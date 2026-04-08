import io


def _tiny_jpeg_bytes() -> bytes:
    """Minimal valid JPEG-blob til upload-tests (1x1 hvidt pixel, ~125 bytes)."""
    return bytes.fromhex(
        "ffd8ffe000104a46494600010100000100010000ffdb004300080606"
        "070605080707070909080a0c140d0c0b0b0c1912130f141d1a1f1e1d"
        "1a1c1c20242e2720222c231c1c2837292c30313434341f27393d3832"
        "3c2e333432ffdb0043010909090c0b0c180d0d1832211c213232323232"
        "32323232323232323232323232323232323232323232323232323232"
        "32323232323232323232323232ffc00011080001000103012200021101"
        "031101ffc4001f0000010501010101010100000000000000000102030"
        "405060708090a0bffc400b5100002010303020403050504040000017d"
        "01020300041105122131410613516107227114328191a1082342b1c11"
        "552d1f02433627282090a161718191a25262728292a3435363738393a"
        "434445464748494a535455565758595a636465666768696a737475767"
        "778797a838485868788898a92939495969798999aa2a3a4a5a6a7a8a9"
        "aab2b3b4b5b6b7b8b9bac2c3c4c5c6c7c8c9cad2d3d4d5d6d7d8d9dae"
        "1e2e3e4e5e6e7e8e9eaf1f2f3f4f5f6f7f8f9faffc4001f01000301010"
        "10101010101010000000000000102030405060708090a0bffc400b511"
        "00020102040403040705040400010277000102031104052131061241"
        "510761711322328108144291a1b1c109233352f0156272d10a162434e"
        "125f11718191a262728292a35363738393a434445464748494a535455"
        "565758595a636465666768696a737475767778797a82838485868788"
        "898a92939495969798999aa2a3a4a5a6a7a8a9aab2b3b4b5b6b7b8b9b"
        "ac2c3c4c5c6c7c8c9cad2d3d4d5d6d7d8d9dae2e3e4e5e6e7e8e9eaf2"
        "f3f4f5f6f7f8f9faffda000c03010002110311003f00fbfcffd9"
    )


def test_upload_scan_returns_scan_id(client, test_db):
    response = client.post(
        "/scans/upload",
        files={"image": ("scan.jpg", io.BytesIO(_tiny_jpeg_bytes()), "image/jpeg")},
    )
    assert response.status_code == 200
    data = response.json()
    assert "scan_id" in data
    assert len(data["scan_id"]) > 0


def test_upload_scan_creates_db_row(client, test_db):
    from app.models.db import Scan

    response = client.post(
        "/scans/upload",
        files={"image": ("scan.jpg", io.BytesIO(_tiny_jpeg_bytes()), "image/jpeg")},
    )
    scan_id = response.json()["scan_id"]

    scan = test_db.query(Scan).filter(Scan.id == scan_id).first()
    assert scan is not None
    assert scan.image_path.endswith(f"scan_{scan_id}.jpg")
    assert "scans/" in scan.image_path
