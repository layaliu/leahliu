#!/usr/bin/env python3
import cv2
import sys


def preprocess(image_path, output_path):
    img = cv2.imread(image_path)
    if img is None:
        return False

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    binary = cv2.adaptiveThreshold(
        gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2
    )
    denoised = cv2.fastNlMeansDenoising(binary, None, 30, 7, 21)
    cv2.imwrite(output_path, denoised)
    return True


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: preprocess_image.py input output")
        sys.exit(1)

    ok = preprocess(sys.argv[1], sys.argv[2])
    sys.exit(0 if ok else 1)
