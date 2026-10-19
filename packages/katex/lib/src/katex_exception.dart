/// The error type raised when KaTeX fails to parse or lay out a formula.
///
/// This is the deliberate twin of `ratex_flutter`'s `RaTeXException`: both
/// carry a single `message` field and both are thrown (not returned) from
/// the `parseAndLayout` entry points, so a caller that migrates between the
/// two engines can swap the type name and keep the `catch` block intact.
///
/// ```dart
/// try {
///   KaTeXEngine.instance.parseAndLayout(r'\frac{a}{');
/// } on KaTeXException catch (e) {
///   print(e.message);
/// }
/// ```
class KaTeXException implements Exception {
  /// Creates an exception carrying a human-readable [message].
  const KaTeXException(this.message);

  /// The human-readable description of the failure.
  final String message;

  @override
  String toString() => 'KaTeXException: $message';
}
