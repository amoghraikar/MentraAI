def test_cv2_import() -> None:
    import cv2
    assert cv2.__version__ is not None


def test_mediapipe_import() -> None:
    import mediapipe as mp
    assert mp.__version__ is not None


def test_numpy_import() -> None:
    import numpy as np
    assert np.__version__ is not None


def test_ultralytics_import() -> None:
    import ultralytics
    from ultralytics import YOLO
    assert ultralytics.__version__ is not None
    assert YOLO is not None


def test_cv_package_structure() -> None:
    import src
    from src import camera, face, eyes, attention, drowsiness, objects, behavior
    assert src is not None
    assert camera is not None
    assert face is not None
    assert eyes is not None
    assert attention is not None
    assert drowsiness is not None
    assert objects is not None
    assert behavior is not None
