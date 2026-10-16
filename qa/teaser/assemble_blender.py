"""Teaser karelerini ve ses bandını H.264 + AAC MP4'e birleştirir (sistemde ffmpeg yok; Blender'ın içindeki kullanılır).
    blender -b --factory-startup --python-exit-code 1 -P qa/teaser/assemble_blender.py -- <kare_klasörü> <ses.wav> <çıktı.mp4>
"""
import os
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
frames_dir, wav, out = args[0], args[1], args[2]
files = sorted(f for f in os.listdir(frames_dir) if f.endswith(".png"))
if not files:
    raise SystemExit("kare yok: " + frames_dir)

scene = bpy.context.scene
scene.render.resolution_x = 1080
scene.render.resolution_y = 1920
scene.render.resolution_percentage = 100
scene.render.fps = 30
scene.render.fps_base = 1.0
scene.frame_start = 1
scene.frame_end = len(files)
seq = scene.sequence_editor_create()
strips = seq.strips if hasattr(seq, "strips") else seq.sequences
img = strips.new_image("kareler", os.path.join(frames_dir, files[0]), channel=1, frame_start=1)
for f in files[1:]:
    img.elements.append(f)
img.frame_final_duration = len(files)
snd = strips.new_sound("ses", wav, channel=2, frame_start=1)
scene.render.image_settings.media_type = "VIDEO"   # Blender 5: önce ortam türü
scene.render.image_settings.file_format = "FFMPEG"
ff = scene.render.ffmpeg
ff.format = "MPEG4"
ff.codec = "H264"
ff.constant_rate_factor = "HIGH"
ff.ffmpeg_preset = "GOOD"
ff.gopsize = 30
ff.audio_codec = "AAC"
ff.audio_bitrate = 256
ff.audio_mixrate = 48000
ff.audio_channels = "STEREO"
scene.render.use_sequencer = True
scene.render.filepath = out
bpy.ops.render.render(animation=True)
print("TEASER MP4:", out, len(files), "kare")
