#!/usr/bin/env python3
import contextlib
import json
import os
import sys
import tempfile
import traceback
from pathlib import Path


REAL_STDOUT = sys.stdout
CONTRAST_FACTOR = 1.35
SHARPNESS_FACTOR = 1.2
DEFAULT_MODEL_PROFILE = "quality"
MODEL_PROFILES = {
    "balanced": {
        "detection": "PP-OCRv5_mobile_det",
        "recognition": "PP-OCRv5_mobile_rec",
        "det_limit": 1920,
        "target_width": 1800,
        "max_upscale": 1.6,
    },
    "quality": {
        "detection": "PP-OCRv5_mobile_det",
        "recognition": "PP-OCRv5_server_rec",
        "det_limit": 1920,
        "target_width": 1800,
        "max_upscale": 1.6,
    },
    "accurate": {
        "detection": "PP-OCRv5_server_det",
        "recognition": "PP-OCRv5_server_rec",
        "det_limit": 2400,
        "target_width": 2200,
        "max_upscale": 2.0,
    },
}


class ClientDisconnected(Exception):
    pass


def silence_stdout():
    try:
        devnull = os.open(os.devnull, os.O_WRONLY)
        try:
            os.dup2(devnull, REAL_STDOUT.fileno())
        finally:
            os.close(devnull)
    except Exception:
        pass


def emit(payload):
    try:
        print(json.dumps(payload, ensure_ascii=False), file=REAL_STDOUT, flush=True)
    except BrokenPipeError as exc:
        silence_stdout()
        raise ClientDisconnected() from exc


def model_settings():
    profile_name = os.environ.get("WEREAD_OCR_MODEL_PROFILE", DEFAULT_MODEL_PROFILE).strip().lower()
    if profile_name not in MODEL_PROFILES:
        profile_name = DEFAULT_MODEL_PROFILE

    settings = dict(MODEL_PROFILES[profile_name])
    settings["profile"] = profile_name
    return settings


def normalize_block(text, score, box):
    if not text:
        return None

    if box is None:
        return None

    if len(box) == 4 and all(isinstance(value, (int, float)) for value in box):
        x1, y1, x2, y2 = box
    else:
        xs = [point[0] for point in box]
        ys = [point[1] for point in box]
        x1, x2 = min(xs), max(xs)
        y1, y2 = min(ys), max(ys)

    return {
        "text": str(text),
        "confidence": float(score) if score is not None else 0.0,
        "box": [float(x1), float(y1), float(x2), float(y2)],
    }


def extract_blocks(result):
    blocks = []

    for page in result:
        payload = getattr(page, "json", None)
        if callable(payload):
            payload = payload()

        if isinstance(payload, dict) and "res" in payload:
            res = payload["res"]
            texts = res.get("rec_texts", [])
            scores = res.get("rec_scores", [])
            boxes = res.get("rec_boxes") or res.get("rec_polys") or res.get("dt_polys") or []

            for index, text in enumerate(texts):
                score = scores[index] if index < len(scores) else None
                box = boxes[index] if index < len(boxes) else None
                block = normalize_block(text, score, box)
                if block is not None:
                    blocks.append(block)

        elif isinstance(page, list):
            for item in page:
                if len(item) < 2:
                    continue
                box = item[0]
                text_info = item[1]
                if isinstance(text_info, (list, tuple)) and len(text_info) >= 2:
                    block = normalize_block(text_info[0], text_info[1], box)
                    if block is not None:
                        blocks.append(block)

    return blocks


def create_ocr():
    os.environ.setdefault("PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK", "True")
    from paddleocr import PaddleOCR
    settings = model_settings()

    return PaddleOCR(
        text_detection_model_name=settings["detection"],
        text_recognition_model_name=settings["recognition"],
        use_doc_orientation_classify=False,
        use_doc_unwarping=False,
        use_textline_orientation=False,
        text_det_limit_side_len=settings["det_limit"],
        text_det_limit_type="max",
    )


def preprocess_image(image_path, settings):
    from PIL import Image, ImageEnhance, ImageOps

    image = Image.open(image_path).convert("RGB")
    width, height = image.size
    target_width = settings["target_width"]
    max_upscale = settings["max_upscale"]

    if width < target_width:
        scale = min(max_upscale, target_width / max(width, 1))
    else:
        scale = 1.0

    if scale > 1.0:
        resized_size = (round(width * scale), round(height * scale))
        image = image.resize(resized_size, Image.Resampling.LANCZOS)

    image = ImageOps.grayscale(image)
    image = ImageOps.autocontrast(image, cutoff=1)
    image = ImageEnhance.Contrast(image).enhance(CONTRAST_FACTOR)
    image = ImageEnhance.Sharpness(image).enhance(SHARPNESS_FACTOR)
    image = image.convert("RGB")

    temp_file = tempfile.NamedTemporaryFile(
        prefix="weread_ocr_preprocessed_",
        suffix=".png",
        delete=False,
    )
    temp_file.close()
    image.save(temp_file.name)

    return temp_file.name, image.size


def predict_blocks(ocr, image_path):
    processed_path = None
    settings = model_settings()

    try:
        processed_path, processed_size = preprocess_image(image_path, settings)
        with contextlib.redirect_stdout(sys.stderr):
            result = ocr.predict(processed_path)

        return extract_blocks(result), processed_size
    finally:
        if processed_path:
            try:
                os.remove(processed_path)
            except FileNotFoundError:
                pass


def run_self_test():
    from PIL import Image, ImageDraw, ImageFont

    image_path = Path("/tmp/wered_paddleocr_self_test.png")
    image = Image.new("RGB", (1440, 360), "white")
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype("/System/Library/Fonts/STHeiti Medium.ttc", 72)
    draw.text((80, 70), "这是微信读书第一页文字", fill="black", font=font)
    draw.text((80, 185), "PaddleOCR 本地识别测试", fill="black", font=font)
    image.save(image_path)

    with contextlib.redirect_stdout(sys.stderr):
        ocr = create_ocr()

    blocks, image_size = predict_blocks(ocr, str(image_path))
    settings = model_settings()
    emit({
        "ok": True,
        "profile": settings["profile"],
        "models": [settings["detection"], settings["recognition"]],
        "image_size": list(image_size),
        "blocks": blocks,
    })

    text = "".join(block["text"] for block in blocks)
    if "微信读书" not in text or "PaddleOCR" not in text:
        raise SystemExit("PaddleOCR self-test did not recognize expected text")


def run_worker():
    with contextlib.redirect_stdout(sys.stderr):
        ocr = create_ocr()

    try:
        settings = model_settings()
        emit({
            "ok": True,
            "ready": True,
            "profile": settings["profile"],
            "models": [settings["detection"], settings["recognition"]],
        })
    except ClientDisconnected:
        return

    for line in sys.stdin:
        try:
            request = json.loads(line)
            image_path = request["image_path"]

            blocks, image_size = predict_blocks(ocr, image_path)

            settings = model_settings()
            emit({
                "ok": True,
                "profile": settings["profile"],
                "models": [settings["detection"], settings["recognition"]],
                "image_size": list(image_size),
                "blocks": blocks,
            })

        except ClientDisconnected:
            return
        except Exception as exc:
            try:
                emit({
                    "ok": False,
                    "error": str(exc),
                    "traceback": traceback.format_exc(),
                })
            except ClientDisconnected:
                return


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        run_self_test()
    else:
        run_worker()
