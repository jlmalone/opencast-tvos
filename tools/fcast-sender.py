#!/usr/bin/env python3
"""Quick FCast protocol sender for testing the receiver in the tvOS simulator.

Usage:
    python3 fcast-sender.py                          # plays test MKV
    python3 fcast-sender.py "http://url/file.mkv" "video/x-matroska"
    python3 fcast-sender.py "http://url/img.png" "image/png"
"""
import socket, struct, json, sys, time

def send_frame(sock, opcode, body=None):
    payload = json.dumps(body).encode() if body else b""
    length = 1 + len(payload)
    sock.sendall(struct.pack("<I", length) + bytes([opcode]) + payload)

def read_frame(sock):
    header = b""
    while len(header) < 4:
        header += sock.recv(4 - len(header))
    length = struct.unpack("<I", header)[0]
    data = b""
    while len(data) < length:
        data += sock.recv(length - len(data))
    opcode = data[0]
    body = data[1:].decode() if length > 1 else None
    return opcode, body

# Test media
TEST_MKV = "https://test-videos.co/pool/Big_Buck_Bunny_1080_10s_5MB.mkv"
TEST_WEBM = "https://test-videos.co/pool/Big_Buck_Bunny_720_10s_2MB.webm"
TEST_MP4 = "https://test-videos.co/pool/Big_Buck_Bunny_1080_10s_5MB.mp4"
TEST_IMAGE = "https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/PNG_transparency_demonstration_1.png/560px-PNG_transparency_demonstration_1.png"

url = sys.argv[1] if len(sys.argv) > 1 else TEST_MKV
container = sys.argv[2] if len(sys.argv) > 2 else {
    ".mkv": "video/x-matroska",
    ".webm": "video/webm",
    ".mp4": "video/mp4",
    ".png": "image/png",
    ".jpg": "image/jpeg",
}.get(url[url.rfind("."):], "video/x-matroska")

print(f"Connecting to localhost:46899...")
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(("127.0.0.1", 46899))
print("Connected!")

# Version handshake
print("-> Sending version...")
send_frame(s, 11, {"version": 3})
op, body = read_frame(s)
print(f"<- Version response (opcode={op}): {body}")

# Play
play_msg = {"container": container, "url": url}
print(f"-> Sending play: {json.dumps(play_msg)}")
send_frame(s, 1, play_msg)

# Listen for updates
OP_NAMES = {6: "PlaybackUpdate", 7: "VolumeUpdate", 9: "PlaybackError"}
print("Listening for playback updates (Ctrl+C to quit)...")
try:
    while True:
        op, body = read_frame(s)
        name = OP_NAMES.get(op, f"Opcode({op})")
        print(f"<- {name}: {body}")
        if op == 9:
            print("ERROR from receiver!")
            break
except (KeyboardInterrupt, Exception) as e:
    print(f"Done: {e}")
finally:
    s.close()
