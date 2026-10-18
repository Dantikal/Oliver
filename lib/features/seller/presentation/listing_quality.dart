import '../../catalog/domain/product.dart';

/// Чего не хватает объявлению — ключ строки-подсказки.
enum QualityTip { photos, description, video, contacts, price }

extension QualityTipX on QualityTip {
  String get l10nKey => switch (this) {
        QualityTip.photos => 'tipPhotos',
        QualityTip.description => 'tipDesc',
        QualityTip.video => 'tipVideo',
        QualityTip.contacts => 'tipContacts',
        QualityTip.price => 'tipPrice',
      };
}

/// Оценка 0..100 и подсказки по порядку важности.
({int score, List<QualityTip> tips}) listingQuality(Product p) {
  var score = 0;
  final tips = <QualityTip>[];
  void check(bool ok, int weight, QualityTip tip) {
    if (ok) {
      score += weight;
    } else {
      tips.add(tip);
    }
  }

  check(p.photoCount >= 3, 30, QualityTip.photos);
  check(p.description.trim().length >= 80, 20, QualityTip.description);
  check(p.currency.isPriceless || (p.price ?? 0) > 0, 15, QualityTip.price);
  check(p.whatsappLink != null || p.telegramLink != null, 15,
      QualityTip.contacts);
  check(p.hasVideo, 10, QualityTip.video);
  // Понятный заголовок — бесплатные 10 баллов, если он не совсем короткий.
  if (p.title.trim().length >= 12) score += 10;
  return (score: score.clamp(0, 100), tips: tips);
}
