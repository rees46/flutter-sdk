import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// The fixture all four SDKs test with: 2×2, 3 frames, delays 10 / 0 / 50 hundredths
/// of a second → 100 + 100 + 500 = 700 ms per loop.
final Uint8List gifFixture = base64Decode(
  'R0lGODlhAgACAIEAAP8AAAD/AAAA/////yH/C05FVFNDQVBFMi4wAwEAAAAh+QQACgAAACwAAAAAAgACAAA'
  'CAoRRACH5BAAAAAAALAAAAAACAAIAAAICjFMAIfkEADIAAAAsAAAAAAIAAgAAAgKUVQA7',
);

/// A codec that needs no real decoding, so it runs on the fake clock of widget tests:
/// frame `i` is an image `i + 1` pixels wide and 1 pixel high, frames loop.
class FakeGifCodec implements ui.Codec {
  FakeGifCodec(this.frameCount);

  @override
  final int frameCount;

  int _next = 0;

  /// Frames handed out so far.
  int decoded = 0;
  bool disposed = false;

  @override
  int get repetitionCount => -1;

  @override
  Future<ui.FrameInfo> getNextFrame() {
    final index = _next;
    _next = (_next + 1) % frameCount;
    decoded++;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(index + 1, 1);
    picture.dispose();
    return Future<ui.FrameInfo>.value(_Frame(image));
  }

  @override
  void dispose() => disposed = true;
}

class _Frame implements ui.FrameInfo {
  _Frame(this.image);

  @override
  final ui.Image image;

  @override
  Duration get duration => Duration.zero;
}
