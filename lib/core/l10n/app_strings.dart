import 'package:flutter/widgets.dart';

/// Лёгкая локализация RU / KY / EN без кодогенерации.
/// Порядок значений: [ru, ky, en].
class AppStrings {
  AppStrings._();

  static const supported = [Locale('ru'), Locale('ky'), Locale('en')];

  static String get(Locale locale, String key) {
    final v = _values[key];
    if (v == null) return key;
    return switch (locale.languageCode) {
      'ky' => v[1],
      'en' => v[2],
      _ => v[0]
    };
  }

  static const _values = <String, List<String>>{
    // Общие
    'tagline': [
      'Покупай. Продавай. Общайся.',
      'Сат. Сатып ал. Сүйлөш.',
      'Buy. Sell. Connect.'
    ],
    'retry': ['Повторить', 'Кайталоо', 'Retry'],
    'cancel': ['Отмена', 'Жокко чыгаруу', 'Cancel'],
    'save': ['Сохранить', 'Сактоо', 'Save'],
    'saved': ['Сохранено', 'Сакталды', 'Saved'],
    'delete': ['Удалить', 'Өчүрүү', 'Delete'],
    'edit': ['Редактировать', 'Өзгөртүү', 'Edit'],
    'add': ['Добавить', 'Кошуу', 'Add'],
    'confirm': ['Подтвердить', 'Ырастоо', 'Confirm'],
    'reset': ['Сбросить', 'Тазалоо', 'Reset'],
    'all': ['Все', 'Баары', 'All'],
    'any': ['Любая', 'Каалаган', 'Any'],
    'or': ['или', 'же', 'or'],
    'optional': ['необязательно', 'милдеттүү эмес', 'optional'],
    'soon': ['Скоро будет', 'Жакында', 'Coming soon'],
    'copied': ['Скопировано', 'Көчүрүлдү', 'Copied'],
    'offline': [
      'Нет соединения с интернетом',
      'Интернет байланышы жок',
      'No internet connection'
    ],
    'endOfList': [
      'Вы посмотрели всё',
      'Баарын көрдүңүз',
      "You're all caught up"
    ],
    'som': ['сом', 'сом', 'KGS'],
    'negotiable': ['Договорная', 'Келишим баада', 'Negotiable'],
    'photo': ['Фото', 'Сүрөт', 'Photo'],
    'video': ['Видео', 'Видео', 'Video'],
    'camera': ['Камера', 'Камера', 'Camera'],
    'today': ['Сегодня', 'Бүгүн', 'Today'],
    'yesterday': ['Вчера', 'Кечээ', 'Yesterday'],
    'justNow': ['только что', 'азыр эле', 'just now'],
    'minAgo': ['{n} мин назад', '{n} мүн мурун', '{n} min ago'],
    'hAgo': ['{n} ч назад', '{n} саат мурун', '{n} h ago'],
    'dAgo': ['{n} дн назад', '{n} күн мурун', '{n} d ago'],

    // Ошибки
    'errGeneric': [
      'Что-то пошло не так. Попробуйте ещё раз',
      'Бир нерсе туура эмес болду. Кайра аракет кылыңыз',
      'Something went wrong. Please try again'
    ],
    'errNetwork': [
      'Проверьте подключение к интернету',
      'Интернетке туташууну текшериңиз',
      'Check your internet connection'
    ],
    'errNetworkTitle': ['Нет сети', 'Тармак жок', 'No connection'],
    'errTitle': ['Упс!', 'Ой!', 'Oops!'],

    // Валидация
    'vRequired': ['Обязательное поле', 'Милдеттүү талаа', 'Required field'],
    'vEmail': [
      'Введите корректный email',
      'Туура email жазыңыз',
      'Enter a valid email'
    ],
    'vPasswordMin': [
      'Минимум 8 символов',
      'Кеминде 8 белги',
      'At least 8 characters'
    ],
    'vPasswordUpper': [
      'Нужна хотя бы одна заглавная буква',
      'Жок дегенде бир баш тамга керек',
      'Add at least one uppercase letter'
    ],
    'vPasswordDigit': [
      'Нужна хотя бы одна цифра',
      'Жок дегенде бир сан керек',
      'Add at least one digit'
    ],
    'vPasswordMatch': [
      'Пароли не совпадают',
      'Сырсөздөр дал келбейт',
      "Passwords don't match"
    ],
    'vPhone': [
      'Введите 9 цифр после +996',
      '+996дан кийин 9 сан жазыңыз',
      'Enter 9 digits after +996'
    ],
    'vName': ['Слишком короткое имя', 'Аты өтө кыска', 'Name is too short'],
    'vLink': ['Некорректная ссылка', 'Шилтеме туура эмес', 'Invalid link'],
    'vPrice': ['Укажите цену', 'Бааны көрсөтүңүз', 'Enter a price'],
    'vDescription': [
      'Минимум 10 символов',
      'Кеминде 10 белги',
      'At least 10 characters'
    ],
    'rule8': ['8+ символов', '8+ белги', '8+ chars'],
    'ruleUpper': ['Заглавная', 'Баш тамга', 'Uppercase'],
    'ruleDigit': ['Цифра', 'Сан', 'Digit'],

    // Авторизация
    'welcomeBack': ['С возвращением!', 'Кош келиңиз!', 'Welcome back!'],
    'loginSub': [
      'Войдите, чтобы продолжить покупки и общение',
      'Улантуу үчүн кириңиз',
      'Sign in to continue'
    ],
    'email': ['Email', 'Email', 'Email'],
    'password': ['Пароль', 'Сырсөз', 'Password'],
    'login': ['Войти', 'Кирүү', 'Sign in'],
    'register': ['Зарегистрироваться', 'Катталуу', 'Sign up'],
    'forgotPassword': [
      'Забыли пароль?',
      'Сырсөздү унуттуңузбу?',
      'Forgot password?'
    ],
    'createAccount': ['Создать аккаунт', 'Аккаунт түзүү', 'Create account'],
    'registerSub': [
      'Пара шагов — и вы в Oliver',
      'Бир нече кадам — жана сиз Oliverде',
      "A few steps and you're in"
    ],
    'phone': ['Номер телефона', 'Телефон номери', 'Phone number'],
    'fullName': ['ФИО', 'Аты-жөнү', 'Full name'],
    'fullNameHint': ['Азамат Токтогулов', 'Азамат Токтогулов', 'John Smith'],
    'confirmPassword': [
      'Подтверждение пароля',
      'Сырсөздү ырастоо',
      'Confirm password'
    ],
    'haveAccount': [
      'Уже есть аккаунт?',
      'Аккаунтуңуз барбы?',
      'Already have an account?'
    ],
    'registered': [
      'Аккаунт создан! Теперь войдите',
      'Аккаунт түзүлдү! Эми кириңиз',
      'Account created! Please sign in'
    ],
    'otpTitle': ['Подтверждение', 'Ырастоо', 'Verification'],
    'otpSub': [
      'Мы отправили 6-значный код на',
      '6 сандуу кодду жөнөттүк:',
      'We sent a 6-digit code to'
    ],
    'resendIn': ['Отправить снова через', 'Кайра жөнөтүү', 'Resend in'],
    'resendCode': [
      'Отправить код повторно',
      'Кодду кайра жөнөтүү',
      'Resend code'
    ],
    'codeResent': [
      'Новый код отправлен',
      'Жаңы код жөнөтүлдү',
      'New code sent'
    ],
    'forgotTitle': ['Восстановление', 'Калыбына келтирүү', 'Reset password'],
    'forgotSub': [
      'Пришлём ссылку для сброса пароля',
      'Сырсөздү алмаштыруу шилтемесин жөнөтөбүз',
      "We'll send you a reset link"
    ],
    'sendLink': ['Отправить ссылку', 'Шилтеме жөнөтүү', 'Send link'],
    'checkEmail': [
      'Проверьте почту',
      'Почтаңызды текшериңиз',
      'Check your inbox'
    ],
    'resetSent': [
      'Ссылка для сброса пароля отправлена на',
      'Шилтеме жөнөтүлдү:',
      'Reset link sent to'
    ],
    'backToLogin': ['Вернуться ко входу', 'Кирүүгө кайтуу', 'Back to sign in'],

    // Навигация
    'navHome': ['Главная', 'Башкы', 'Home'],
    'navFavorites': ['Избранное', 'Тандалма', 'Saved'],
    'navChats': ['Чаты', 'Чаттар', 'Chats'],
    'navProfile': ['Профиль', 'Профиль', 'Profile'],

    // Главная
    'fxTitle': ['Курс НБКР', 'УКБ курсу', 'NBKR rate'],
    'fxStale': ['нет сети', 'тармак жок', 'offline'],
    'priceIn': ['Цены', 'Баалар', 'Prices'],
    'asListed': ['Как есть', 'Кандай болсо', 'As listed'],
    'converter': ['Конвертер валют', 'Валюта конвертери', 'Currency converter'],
    'amount': ['Сумма', 'Сумма', 'Amount'],
    'fxNote': [
      'По официальному курсу НБКР на',
      'УКБнын расмий курсу боюнча,',
      'Official NBKR rate as of'
    ],
    'byNbkr': ['по курсу НБКР', 'УКБ курсу боюнча', 'at NBKR rate'],
    'goodMorning': ['Доброе утро', 'Кутман таң', 'Good morning'],
    'goodDay': ['Добрый день', 'Кутман күн', 'Good afternoon'],
    'goodEvening': ['Добрый вечер', 'Кутман кеч', 'Good evening'],
    'goodNight': ['Доброй ночи', 'Бейпил түн', 'Good night'],
    'homeTitleA': ['Что ищем', 'Бүгүн', 'What are we'],
    'homeTitleB': ['сегодня?', 'эмне издейбиз?', 'looking for?'],
    'searchHints': [
      'iPhone 15 Pro|Квартира в Бишкеке|Toyota Camry|Скакун|Диван|PlayStation 5',
      'iPhone 15 Pro|Бишкектен батир|Toyota Camry|Күлүк ат|Диван|PlayStation 5',
      'iPhone 15 Pro|Flat in Bishkek|Toyota Camry|Horse|Sofa|PlayStation 5'
    ],
    'sellerCabinet': [
      'Кабинет продавца',
      'Сатуучунун кабинети',
      'Seller dashboard'
    ],
    'sellerSub': [
      'Ваши продажи на Oliver',
      'Oliverдеги сатууларыңыз',
      'Your sales on Oliver'
    ],
    'days7': ['7 дней', '7 күн', '7 days'],
    'days30': ['30 дней', '30 күн', '30 days'],
    'statViews': ['Просмотры', 'Көрүүлөр', 'Views'],
    'statSaved': ['В избранном', 'Тандалгандарда', 'Saved'],
    'statChats': ['Чаты', 'Чаттар', 'Chats'],
    'statActive': ['Активные', 'Активдүү', 'Active'],
    'vsPrev': ['к прошлому', 'мурункуга', 'vs prev.'],
    'viewsByDay': ['Просмотры по дням', 'Күн боюнча көрүүлөр', 'Views by day'],
    'tabActive': ['Активные', 'Активдүү', 'Active'],
    'tabSold': ['Проданные', 'Сатылган', 'Sold'],
    'tabArchive': ['Архив', 'Архив', 'Archive'],
    'bump': ['Поднять', 'Көтөрүү', 'Bump'],
    'bumped': [
      'Объявление поднято в ленте',
      'Жарыя тасмада көтөрүлдү',
      'Listing bumped to the top'
    ],
    'markSold': ['Продано', 'Сатылды', 'Mark sold'],
    'toArchive': ['В архив', 'Архивге', 'Archive'],
    'restore': ['Вернуть в продажу', 'Кайра сатууга', 'Back on sale'],
    'markedSold': [
      'Отмечено как проданное',
      'Сатылды деп белгиленди',
      'Marked as sold'
    ],
    'archivedMsg': [
      'Перенесено в архив',
      'Архивге которулду',
      'Moved to archive'
    ],
    'restoredMsg': ['Снова в продаже', 'Кайра сатыкта', 'Back on sale'],
    'soldStamp': ['ПРОДАНО', 'САТЫЛДЫ', 'SOLD'],
    'quality': ['Качество', 'Сапаты', 'Quality'],
    'qualityGood': ['Отличное объявление', 'Мыкты жарыя', 'Great listing'],
    'tipPhotos': [
      'Добавьте фото — лучше 3 и больше',
      'Сүрөт кошуңуз — 3төн көп',
      'Add photos — 3 or more'
    ],
    'tipDesc': [
      'Опишите товар подробнее',
      'Товарды кененирээк сүрөттөңүз',
      'Write a fuller description'
    ],
    'tipVideo': [
      'Добавьте короткое видео',
      'Кыска видео кошуңуз',
      'Add a short video'
    ],
    'tipContacts': [
      'Укажите WhatsApp или Telegram',
      'WhatsApp же Telegram кошуңуз',
      'Add WhatsApp or Telegram'
    ],
    'tipPrice': ['Укажите цену', 'Баасын жазыңыз', 'Set a price'],
    'sellTips': ['Как продать быстрее', 'Кантип тезирээк сатуу', 'Sell faster'],
    'tipsAds': ['объявл.', 'жарыя', 'ads'],
    'noSold': [
      'Пока ничего не продано',
      'Азырынча эч нерсе сатылган жок',
      'Nothing sold yet'
    ],
    'noSoldSub': [
      'Отмечайте проданное — так покупатели не будут писать зря',
      'Сатылганды белгилеңиз',
      'Mark sold items so buyers don\'t message in vain'
    ],
    'noArchive': ['Архив пуст', 'Архив бош', 'Archive is empty'],
    'noArchiveSub': [
      'Сюда попадают снятые с продажи объявления',
      'Бул жерге сатуудан алынган жарыялар түшөт',
      'Listings you take off sale land here'
    ],
    'weekdaysShort': [
      'Пн|Вт|Ср|Чт|Пт|Сб|Вс',
      'Дш|Шш|Шр|Бш|Жм|Иш|Жк',
      'Mo|Tu|We|Th|Fr|Sa|Su'
    ],
    'myStore': ['Мой магазин', 'Менин дүкөнүм', 'My store'],
    'store': ['Магазин', 'Дүкөн', 'Store'],
    'storeSub': [
      'Отделы, порядок товаров и витрина для покупателей',
      'Бөлүмдөр, товарлардын тартиби жана витрина',
      'Sections, product order and a storefront'
    ],
    'createStore': ['Открыть магазин', 'Дүкөн ачуу', 'Open a store'],
    'createStoreSub': [
      'Разложите товары по отделам — покупателям будет проще выбирать, а вам продавать',
      'Товарларды бөлүмдөргө бөлүңүз — сатып алуучуларга тандоо оңой болот',
      'Sort your items into sections — easier to shop, easier to sell'
    ],
    'storeName': ['Название магазина', 'Дүкөндүн аталышы', 'Store name'],
    'storeDesc': [
      'Пара слов о магазине',
      'Дүкөн тууралуу бир-эки сөз',
      'A few words about the store'
    ],
    'storeInfo': ['Информация', 'Маалымат', 'Details'],
    'pickup': ['Самовывоз', 'Өзү алып кетүү', 'Pickup'],
    'deliveryOpt': ['Доставка', 'Жеткирүү', 'Delivery'],
    'sections': ['Отделы', 'Бөлүмдөр', 'Sections'],
    'addSection': ['Добавить отдел', 'Бөлүм кошуу', 'Add section'],
    'newSection': ['Новый отдел', 'Жаңы бөлүм', 'New section'],
    'sectionName': ['Название отдела', 'Бөлүмдүн аталышы', 'Section name'],
    'sectionIcon': ['Иконка', 'Белги', 'Icon'],
    'deleteSectionQ': [
      'Удалить отдел?',
      'Бөлүмдү өчүрөсүзбү?',
      'Delete section?'
    ],
    'deleteSectionSub': [
      'Товары останутся в магазине, просто без отдела',
      'Товарлар дүкөндө калат, бөлүмсүз',
      'Items stay in the store, just without a section'
    ],
    'noSection': ['Без отдела', 'Бөлүмсүз', 'No section'],
    'hits': ['Хиты', 'Хиттер', 'Top picks'],
    'makeHit': ['Сделать хитом', 'Хит кылуу', 'Make a top pick'],
    'removeHit': ['Убрать из хитов', 'Хиттерден алуу', 'Remove from top picks'],
    'moveTo': ['Перенести в отдел', 'Бөлүмгө которуу', 'Move to section'],
    'removeFromSection': [
      'Убрать из отдела',
      'Бөлүмдөн алуу',
      'Remove from section'
    ],
    'addProducts': ['Добавить товары', 'Товар кошуу', 'Add items'],
    'addN': ['Добавить', 'Кошуу', 'Add'],
    'itemsShort': ['товаров', 'товар', 'items'],
    'itemsCap': ['Товары', 'Товарлар', 'Items'],
    'sortBy': ['Упорядочить', 'Иреттөө', 'Arrange'],
    'sortSeller': ['Порядок продавца', 'Сатуучунун ирети', 'Seller order'],
    'sortNewest': ['Новые', 'Жаңылар', 'Newest'],
    'sortCheap': ['Дешевле', 'Арзаныраак', 'Cheapest'],
    'sortExpensive': ['Дороже', 'Кымбатыраак', 'Priciest'],
    'sortPopular': ['Популярные', 'Популярдуу', 'Popular'],
    'sortName': ['По названию', 'Аталышы боюнча', 'By name'],
    'dragHint': [
      'Зажмите ≡ и перетащите, чтобы поменять порядок',
      'Тартипти өзгөртүү үчүн ≡ басып сүйрөңүз',
      'Hold ≡ and drag to reorder'
    ],
    'openStorefront': ['Витрина', 'Витрина', 'Storefront'],
    'shareStore': ['Поделиться', 'Бөлүшүү', 'Share'],
    'searchInStore': [
      'Поиск в магазине',
      'Дүкөндөн издөө',
      'Search this store'
    ],
    'allItems': ['Все', 'Баары', 'All'],
    'emptySection': [
      'В отделе пока пусто',
      'Бөлүм азырынча бош',
      'This section is empty'
    ],
    'emptySectionSub': [
      'Добавьте сюда товары из своих объявлений',
      'Бул жерге жарыяларыңыздан товар кошуңуз',
      'Add items from your listings'
    ],
    'allPlaced': [
      'Все товары уже разложены',
      'Бардык товарлар бөлүштүрүлгөн',
      'Every item is already placed'
    ],
    'unsortedTip': [
      'не разложены по отделам',
      'бөлүмдөргө бөлүнгөн эмес',
      'not in any section'
    ],
    'hello': ['Привет', 'Салам', 'Hi'],
    'homeTitle': [
      'Что ищем сегодня?',
      'Бүгүн эмне издейбиз?',
      'What are we looking for?'
    ],
    'searchHint': [
      'Поиск товаров и услуг',
      'Товарларды издөө',
      'Search products & services'
    ],
    'freshAds': ['Свежие объявления', 'Жаңы жарыялар', 'Fresh listings'],
    'voiceMessage': ['Голосовое', 'Үн кабар', 'Voice message'],
    'changeCover': ['Фон', 'Фон', 'Cover'],
    'coverTitle': ['Фон профиля', 'Профилдин фону', 'Profile cover'],
    'ownPhoto': ['Своё фото', 'Өз сүрөтүң', 'Your photo'],
    'coverForest': ['Лес', 'Токой', 'Forest'],
    'coverOlive': ['Олива', 'Зайтун', 'Olive'],
    'coverLime': ['Лайм', 'Лайм', 'Lime'],
    'coverPaper': ['Бумага', 'Кагаз', 'Paper'],
    'coverNight': ['Ночь', 'Түн', 'Night'],
    'coverSage': ['Шалфей', 'Шалфей', 'Sage'],
    'postAd': ['Разместить объявление', 'Жарыя берүү', 'Post an ad'],
    'recording': ['Запись…', 'Жазылууда…', 'Recording…'],
    'micDenied': [
      'Нет доступа к микрофону. Разрешите его в настройках',
      'Микрофонго уруксат жок. Жөндөөлөрдөн уруксат бериңиз',
      'No microphone access. Allow it in Settings'
    ],
    'tooShort': ['Слишком короткое', 'Өтө кыска', 'Too short'],
    'editorsPick': ['Выбор редакции', 'Редакциянын тандоосу', 'Editor\'s pick'],
    'editorsPickSub': [
      'Самое заметное за неделю',
      'Жуманын эң көрүнүктүүлөрү',
      'Standouts of the week'
    ],
    'ticker': [
      'Покупай · Продавай · Всё что угодно · Бишкек · Ош · Каракол · Джалал-Абад',
      'Сатып ал · Сат · Баары бар · Бишкек · Ош · Каракол · Жалал-Абад',
      'Buy · Sell · Everything · Bishkek · Osh · Karakol · Jalal-Abad'
    ],
    'searchResults': ['Результаты', 'Натыйжалар', 'Results'],
    'adsShort': ['объявл.', 'жарыя', 'ads'],
    'nothingFound': [
      'Ничего не нашли',
      'Эч нерсе табылган жок',
      'Nothing found'
    ],
    'nothingFoundSub': [
      'Попробуйте изменить запрос или фильтры',
      'Суроону же чыпкаларды өзгөртүп көрүңүз',
      'Try changing your query or filters'
    ],
    'resetFilters': ['Сбросить фильтры', 'Чыпкаларды тазалоо', 'Reset filters'],
    'promoTag': ['НОВОЕ', 'ЖАҢЫ', 'NEW'],
    'promoTitle': [
      'Продай ненужное за 2 минуты',
      'Керексизди 2 мүнөттө сат',
      'Sell stuff in 2 minutes'
    ],
    'promoAction': ['Разместить объявление', 'Жарыя берүү', 'Post a listing'],
    'filters': ['Фильтры', 'Чыпкалар', 'Filters'],
    'category': ['Категория', 'Категория', 'Category'],
    'price': ['Цена', 'Баасы', 'Price'],
    'from': ['от', 'баштап', 'from'],
    'to': ['до', 'чейин', 'to'],
    'currency': ['Валюта', 'Валюта', 'Currency'],
    'location': ['Местоположение', 'Жайгашкан жер', 'Location'],
    'region': ['Область', 'Облус', 'Region'],
    'city': ['Город', 'Шаар', 'City'],
    'allRegions': ['Все области', 'Бардык облустар', 'All regions'],
    'allCities': ['Все города', 'Бардык шаарлар', 'All cities'],
    'sort': ['Сортировка', 'Иреттөө', 'Sort'],
    'sort_newest': ['Сначала новые', 'Адегенде жаңылар', 'Newest'],
    'sort_cheap': ['Дешевле', 'Арзаныраак', 'Cheapest'],
    'sort_expensive': ['Дороже', 'Кымбатыраак', 'Most expensive'],
    'showResults': [
      'Показать результаты',
      'Натыйжаларды көрсөтүү',
      'Show results'
    ],

    // Товар
    'description': ['Описание', 'Сүрөттөмө', 'Description'],
    'share': ['Поделиться', 'Бөлүшүү', 'Share'],
    'copyLink': ['Ссылка', 'Шилтеме', 'Link'],
    'linkCopied': ['Ссылка скопирована', 'Шилтеме көчүрүлдү', 'Link copied'],
    'comments': ['Комментарии', 'Комментарийлер', 'Comments'],
    'seller': ['Продавец', 'Сатуучу', 'Seller'],
    'verified': ['Проверенный', 'Текшерилген', 'Verified'],
    'goToChat': ['Перейти в чат', 'Чатка өтүү', 'Message seller'],
    'toChat': ['В чат', 'Чатка', 'Chat'],
    'editAd': ['Редактировать', 'Жарыяны өзгөртүү', 'Edit listing'],

    // Комментарии
    'reply': ['Ответить', 'Жооп берүү', 'Reply'],
    'replyTo': ['Ответ для', 'Жооп:', 'Replying to'],
    'showReplies': [
      'Показать ответы ({n})',
      'Жоопторду көрсөтүү ({n})',
      'View replies ({n})'
    ],
    'writeComment': [
      'Написать комментарий…',
      'Комментарий жазуу…',
      'Add a comment…'
    ],
    'noComments': [
      'Пока без комментариев',
      'Азырынча комментарий жок',
      'No comments yet'
    ],
    'noCommentsSub': [
      'Будьте первым — задайте вопрос продавцу',
      'Биринчи болуңуз — сатуучуга суроо бериңиз',
      'Be the first to ask the seller'
    ],
    'deleteCommentQ': [
      'Удалить комментарий?',
      'Комментарийди өчүрөсүзбү?',
      'Delete comment?'
    ],
    'deleteCommentSub': [
      'Это действие нельзя отменить',
      'Бул аракетти артка кайтаруу мүмкүн эмес',
      "This can't be undone"
    ],

    // Создание
    'newAd': ['Новое объявление', 'Жаңы жарыя', 'New listing'],
    'photoVideo': ['Фото и видео', 'Сүрөт жана видео', 'Photos & videos'],
    'photoShort': ['фото', 'сүрөт', 'photos'],
    'videoShort': ['видео', 'видео', 'videos'],
    'reorderHint': [
      'Нажмите на фото — сделать обложкой. Удерживайте и тяните — изменить порядок',
      'Сүрөттү басыңыз — мукаба кылуу. Кармап сүйрөңүз — тартибин өзгөртүү',
      'Tap a photo to make it the cover. Long-press & drag to reorder'
    ],
    'cover': ['Обложка', 'Мукаба', 'Cover'],
    'aboutAd': ['Основное', 'Негизги', 'Basics'],
    'title': ['Название', 'Аталышы', 'Title'],
    'titleHint': [
      'Например, iPhone 15 Pro 256GB',
      'Мисалы, iPhone 15 Pro 256GB',
      'e.g. iPhone 15 Pro 256GB'
    ],
    'chooseCategory': [
      'Выберите категорию',
      'Категорияны тандаңыз',
      'Choose a category'
    ],
    'chooseRegion': ['Выберите область', 'Облусту тандаңыз', 'Choose a region'],
    'chooseCity': ['Выберите город', 'Шаарды тандаңыз', 'Choose a city'],
    'chooseRegionFirst': [
      'Сначала выберите область',
      'Адегенде облусту тандаңыз',
      'Choose a region first'
    ],
    'descriptionHint': [
      'Состояние, комплектация, особенности…',
      'Абалы, комплектациясы, өзгөчөлүктөрү…',
      'Condition, what’s included, details…'
    ],
    'contacts': ['Контакты', 'Байланыш', 'Contacts'],
    'whatsapp': ['WhatsApp', 'WhatsApp', 'WhatsApp'],
    'telegram': ['Telegram', 'Telegram', 'Telegram'],
    'publish': ['Опубликовать', 'Жарыялоо', 'Publish'],
    'photoFromGallery': [
      'Фото из галереи',
      'Галереядан сүрөт',
      'Photo from gallery'
    ],
    'takePhoto': ['Сделать фото', 'Сүрөткө тартуу', 'Take a photo'],
    'videoFromGallery': [
      'Видео из галереи',
      'Галереядан видео',
      'Video from gallery'
    ],
    'fromFiles': ['Из файлов', 'Файлдардан', 'From files'],
    'badFormat': [
      'Неподдерживаемый формат',
      'Колдоого алынбаган формат',
      'Unsupported format'
    ],
    'fileTooBig': [
      'Файл больше {n} МБ',
      'Файл {n} МБдан чоң',
      'File is larger than {n} MB'
    ],
    'limitReached': [
      'Максимум {n} файлов',
      'Эң көп {n} файл',
      'Maximum {n} files'
    ],
    'fillRequired': [
      'Заполните обязательные поля и добавьте хотя бы одно фото',
      'Милдеттүү талааларды толтуруп, жок дегенде бир сүрөт кошуңуз',
      'Fill in required fields and add at least one photo'
    ],
    'uploadingMedia': [
      'Загружаем медиа',
      'Медиа жүктөлүүдө',
      'Uploading media'
    ],
    'adPublished': [
      'Объявление опубликовано',
      'Жарыя жарыяланды',
      'Listing published'
    ],
    'adUpdated': [
      'Изменения сохранены',
      'Өзгөртүүлөр сакталды',
      'Changes saved'
    ],

    // Отдам даром
    'free': ['Даром', 'Бекер', 'Free'],
    'giveaway': ['Отдам даром', 'Бекер берем', 'Giveaway'],
    'giveawaySub': [
      'Вещи, которые отдают бесплатно',
      'Бекер берилген буюмдар',
      'Things people give away for free'
    ],
    'giveawayPriceNote': [
      'Цена не нужна — покупатели увидят «Даром»',
      'Баа керек эмес — сатып алуучулар «Бекер» деп көрөт',
      'No price needed — buyers will see “Free”'
    ],
    'seeAll': ['Смотреть все', 'Баарын көрүү', 'See all'],

    // Корзина и покупка
    'cart': ['Корзина', 'Себет', 'Cart'],
    'cartEmpty': ['Корзина пуста', 'Себет бош', 'Your cart is empty'],
    'cartEmptySub': [
      'Добавляйте товары кнопкой «В корзину» — и оформляйте у продавца',
      '«Себетке» баскычы менен кошуп, сатуучудан тапшырыңыз',
      'Tap “Add to cart” on a listing, then order from the seller'
    ],
    'toShopping': ['К покупкам', 'Сатып алууга', 'Start shopping'],
    'addToCart': ['В корзину', 'Себетке', 'Add to cart'],
    'buyNow': ['Купить', 'Сатып алуу', 'Buy now'],
    'addedToCart': ['Добавлено в корзину', 'Себетке кошулду', 'Added to cart'],
    'quantity': ['Количество', 'Саны', 'Quantity'],
    'chooseOptions': ['Выберите', 'Тандаңыз', 'Choose'],
    'orderTotal': ['Итого', 'Жалпы', 'Total'],
    'orderHello': [
      'Здравствуйте! Хочу заказать:',
      'Саламатсызбы! Буйрутма бергим келет:',
      'Hi! I’d like to order:'
    ],
    'checkoutSeller': [
      'Оформить у продавца',
      'Сатуучудан буйрутма берүү',
      'Order from seller'
    ],
    'orderSent': [
      'Заказ отправлен продавцу в чат',
      'Буйрутма сатуучуга чатка жөнөтүлдү',
      'Order sent to the seller in chat'
    ],
    'call': ['Позвонить', 'Чалуу', 'Call'],
    'done': ['Готово', 'Даяр', 'Done'],

    // Варианты товара
    'variants': ['Варианты', 'Варианттар', 'Options'],
    'chooseVariant': ['Выбрать', 'Тандоо', 'Choose'],
    'variantsHint': [
      'Модель, цвет, размер — покупатель выберет нужное при заказе',
      'Модель, түс, өлчөм — сатып алуучу буйрутмада тандайт',
      'Model, colour, size — the buyer picks one when ordering'
    ],
    'addVariantGroup': ['Добавить вариант', 'Вариант кошуу', 'Add option'],
    'optModel': ['Модель', 'Модель', 'Model'],
    'optColor': ['Цвет', 'Түс', 'Colour'],
    'optSize': ['Размер', 'Өлчөм', 'Size'],
    'optMemory': ['Память', 'Эс тутум', 'Storage'],
    'optCustom': ['Свой вариант', 'Өз вариантыңыз', 'Custom option'],
    'optCustomName': ['Название варианта', 'Варианттын аталышы', 'Option name'],
    'optCustomHint': [
      'Например, материал или вкус',
      'Мисалы, материал же даам',
      'e.g. material or flavour'
    ],
    'optValueHint': [
      'Введите значение и нажмите +',
      'Маанини жазып, + басыңыз',
      'Type a value and tap +'
    ],
    'colBlack': ['Чёрный', 'Кара', 'Black'],
    'colWhite': ['Белый', 'Ак', 'White'],
    'colGray': ['Серый', 'Боз', 'Grey'],
    'colSilver': ['Серебристый', 'Күмүш', 'Silver'],
    'colGold': ['Золотой', 'Алтын', 'Gold'],
    'colBeige': ['Бежевый', 'Беж', 'Beige'],
    'colBrown': ['Коричневый', 'Күрөң', 'Brown'],
    'colRed': ['Красный', 'Кызыл', 'Red'],
    'colPink': ['Розовый', 'Кызгылт', 'Pink'],
    'colOrange': ['Оранжевый', 'Кызгылт сары', 'Orange'],
    'colYellow': ['Жёлтый', 'Сары', 'Yellow'],
    'colGreen': ['Зелёный', 'Жашыл', 'Green'],
    'colBlue': ['Синий', 'Көк', 'Blue'],
    'colPurple': ['Фиолетовый', 'Кызгылт көк', 'Purple'],

    // Фильтр
    'withVideo': ['Только с видео', 'Видеосу барлар', 'With video only'],
    'priceUpTo': ['до {n}', '{n} чейин', 'up to {n}'],
    'priceFrom': ['от {n}', '{n} баштап', 'from {n}'],
    'subcategory': ['Подкатегория', 'Ички категория', 'Subcategory'],
    'showN': ['Показать {n}', '{n} көрсөтүү', 'Show {n}'],
    'nothingMatches': [
      'Ничего не найдено',
      'Эч нерсе табылган жок',
      'Nothing matches'
    ],

    // Конструктор объявления
    'newAdSimilar': ['Похожее объявление', 'Окшош жарыя', 'Similar listing'],
    'preview': ['Предпросмотр', 'Алдын ала көрүү', 'Preview'],
    'previewTitle': [
      'Так увидят покупатели',
      'Сатып алуучулар ушундай көрөт',
      'How buyers will see it'
    ],
    'previewInFeed': ['В ленте', 'Тасмада', 'In the feed'],
    'previewInList': ['Списком', 'Тизме менен', 'As a list'],
    'untitled': ['Без названия', 'Аталышы жок', 'Untitled'],
    'draft': ['Черновик', 'Долбоор', 'Draft'],
    'draftRestored': [
      'Продолжаем ваш черновик',
      'Долбооруңузду улантабыз',
      'Picking up your draft'
    ],
    'startOver': ['Начать заново', 'Кайра баштоо', 'Start over'],
    'draftSaved': [
      'Черновик сохранён — вернитесь к нему в любой момент',
      'Долбоор сакталды — каалаган убакта кайтыңыз',
      'Draft saved — come back anytime'
    ],
    'continueDraft': ['Продолжить', 'Улантуу', 'Continue'],
    'draftDeleteQ': [
      'Удалить черновик?',
      'Долбоорду өчүрөсүзбү?',
      'Delete the draft?'
    ],
    'savedAgo': ['сохранён {t}', 'сакталды {t}', 'saved {t}'],
    'discardQ': [
      'Выйти без сохранения?',
      'Сактабай чыгасызбы?',
      'Leave without saving?'
    ],
    'discardSub': [
      'Изменения в объявлении будут потеряны',
      'Жарыядагы өзгөртүүлөр жоголот',
      'Your changes to this listing will be lost'
    ],
    'leave': ['Выйти', 'Чыгуу', 'Leave'],
    'recentCats': ['Недавние', 'Акыркылар', 'Recent'],
    'priceHint': [
      'Похожие продают за',
      'Окшоштору сатылууда',
      'Similar listings sell for'
    ],
    'priceTypical': ['обычно', 'адатта', 'typically'],
    'usePrice': ['Подставить', 'Коюу', 'Use'],
    'quickPhrases': ['Быстрые фразы', 'Тез сөздөр', 'Quick phrases'],
    'phNew': [
      'Новый, не использовался',
      'Жаңы, колдонулган эмес',
      'Brand new, never used'
    ],
    'phUsed': [
      'Б/у, в отличном состоянии',
      'Колдонулган, абалы мыкты',
      'Used, excellent condition'
    ],
    'phBox': [
      'Полный комплект, есть коробка',
      'Толук комплект, кутусу бар',
      'Complete set, original box'
    ],
    'phBargain': [
      'Небольшой торг уместен',
      'Бир аз соодалашууга болот',
      'Open to reasonable offers'
    ],
    'phDelivery': [
      'Возможна доставка по городу',
      'Шаар ичинде жеткирип берем',
      'City delivery available'
    ],
    'phNoSwap': [
      'Обмен не предлагать',
      'Алмашуу сунуштабаңыз',
      'No swaps, please'
    ],
    'phWarranty': ['Есть гарантия', 'Кепилдиги бар', 'Under warranty'],
    'waFromPhone': [
      'WhatsApp на этот же номер',
      'WhatsApp ушул эле номерге',
      'WhatsApp on this number'
    ],
    'makeCover': ['Сделать обложкой', 'Мукаба кылуу', 'Set as cover'],
    'qualityChecklist': [
      'Чек-лист объявления',
      'Жарыянын чек-барагы',
      'Listing checklist'
    ],
    'qualitySub': [
      'Чем полнее объявление, тем больше просмотров и звонков',
      'Жарыя толук болгон сайын көрүү жана чалуу көбөйөт',
      'Fuller listings get more views and calls'
    ],
    'tipTitle': [
      'Понятное название — от 12 символов',
      'Түшүнүктүү аталыш — 12 белгиден',
      'Clear title — 12+ characters'
    ],
    'requiredLeft': [
      'Обязательных осталось: {n}',
      'Милдеттүүлөрдөн калды: {n}',
      'Required left: {n}'
    ],
    'readyToPublish': [
      'Можно публиковать',
      'Жарыялоого даяр',
      'Ready to publish'
    ],

    // Управление объявлениями
    'makeSimilar': ['Создать похожее', 'Окшошун түзүү', 'Duplicate'],
    'changePrice': ['Изменить цену', 'Бааны өзгөртүү', 'Change price'],
    'priceUpdated': ['Цена обновлена', 'Баа жаңыланды', 'Price updated'],
    'searchMyAds': [
      'Найти среди своих',
      'Өзүмдүкүнөн издөө',
      'Search my listings'
    ],
    'sortViews': ['Просмотры', 'Көрүүлөр', 'Most viewed'],
    'sortAttention': [
      'Требуют внимания',
      'Көңүл бурууну талап кылат',
      'Needs attention'
    ],
    'selectedN': ['Выбрано: {n}', 'Тандалды: {n}', '{n} selected'],
    'selectAll': ['Выбрать все', 'Баарын тандоо', 'Select all'],
    'bulkDone': [
      'Готово: {n} объявл.',
      'Даяр: {n} жарыя',
      'Done: {n} listings'
    ],
    'deleteAdsQ': [
      'Удалить объявления: {n}?',
      'Жарыяларды өчүрөсүзбү: {n}?',
      'Delete {n} listings?'
    ],
    'longPressHint': [
      'Удерживайте объявление, чтобы выбрать несколько',
      'Бир нечесин тандоо үчүн жарыяны кармап туруңуз',
      'Long-press a listing to select several'
    ],
    'improve': ['Улучшить', 'Жакшыртуу', 'Improve'],

    // Избранное
    'favorites': ['Избранное', 'Тандалмалар', 'Saved'],
    'favoritesSub': [
      'Всё, что вам понравилось',
      'Сизге жаккандардын баары',
      'Everything you liked'
    ],
    'favEmpty': ['Здесь пока пусто', 'Азырынча бош', 'Nothing here yet'],
    'favEmptySub': [
      'Нажимайте на сердечко в объявлениях, чтобы сохранить их здесь',
      'Сактоо үчүн жарыялардагы жүрөкчөнү басыңыз',
      'Tap the heart on listings to save them here'
    ],
    'browseAds': ['Смотреть объявления', 'Жарыяларды көрүү', 'Browse listings'],
    'removedFromFav': [
      'Удалено из избранного',
      'Тандалмалардан өчүрүлдү',
      'Removed from saved'
    ],

    // Чаты
    'chats': ['Чаты', 'Чаттар', 'Chats'],
    'messages': ['Сообщения', 'Билдирүүлөр', 'Messages'],
    'activity': ['Активность', 'Активдүүлүк', 'Activity'],
    'noChats': ['Нет чатов', 'Чаттар жок', 'No chats yet'],
    'noChatsSub': [
      'Напишите продавцу — переписка появится здесь',
      'Сатуучуга жазыңыз — кат алышуу ушул жерде болот',
      'Message a seller to start a chat'
    ],
    'noActivity': ['Пока тихо', 'Азырынча тынч', 'All quiet'],
    'noActivitySub': [
      'Лайки и комментарии к вашим товарам появятся здесь',
      'Товарларыңызга лайктар жана комментарийлер ушул жерде',
      'Likes & comments on your listings appear here'
    ],
    'startChat': [
      'Начните диалог',
      'Сүйлөшүүнү баштаңыз',
      'Start the conversation'
    ],
    'message': ['Сообщение', 'Билдирүү', 'Message'],
    'typing': ['печатает…', 'жазып жатат…', 'typing…'],
    'online': ['в сети', 'тармакта', 'online'],
    'recently': ['был(а) недавно', 'жакында болгон', 'last seen recently'],
    'sayHi': ['Скажите «Салам!»', '«Салам!» деңиз', 'Say hi!'],
    'sayHiSub': [
      'Начните разговор с продавцом',
      'Сатуучу менен сүйлөшүүнү баштаңыз',
      'Start a conversation with the seller'
    ],

    // Профиль
    'myAds': ['Мои объявления', 'Менин жарыяларым', 'My listings'],
    'noMyAds': [
      'У вас ещё нет объявлений',
      'Сизде азырынча жарыя жок',
      'No listings yet'
    ],
    'noMyAdsSub': [
      'Разместите первое — это займёт пару минут',
      'Биринчисин жайгаштырыңыз — бир нече мүнөт',
      'Post your first one in a couple of minutes'
    ],
    'deleteAdQ': [
      'Удалить объявление?',
      'Жарыяны өчүрөсүзбү?',
      'Delete listing?'
    ],
    'adDeleted': ['Объявление удалено', 'Жарыя өчүрүлдү', 'Listing deleted'],
    'editName': ['Изменить имя', 'Атын өзгөртүү', 'Edit name'],
    'avatarUpdated': ['Аватар обновлён', 'Аватар жаңыланды', 'Avatar updated'],
    'write': ['Написать', 'Жазуу', 'Message'],
    'userAds': ['Объявления', 'Жарыялар', 'Listings'],
    'noUserAds': ['Нет объявлений', 'Жарыялар жок', 'No listings'],
    'noUserAdsSub': [
      'У пользователя пока нет активных объявлений',
      'Колдонуучуда азырынча активдүү жарыя жок',
      'This user has no active listings'
    ],
    'onOliverSince': ['На Oliver с', 'Oliverде', 'On Oliver since'],

    // Настройки
    'settings': ['Настройки', 'Жөндөөлөр', 'Settings'],
    'notifications': ['Уведомления', 'Билдирмелер', 'Notifications'],
    'pushNotifications': [
      'Push-уведомления',
      'Push-билдирмелер',
      'Push notifications'
    ],
    'pushSub': [
      'Сообщения, лайки и комментарии',
      'Билдирүүлөр, лайктар, комментарийлер',
      'Messages, likes and comments'
    ],
    'chatSounds': ['Звуки в чате', 'Чаттагы үндөр', 'Chat sounds'],
    'uiSounds': ['Звуки нажатий', 'Басуу үндөрү', 'Tap sounds'],
    'uiSoundsSub': [
      'Мягкий щелчок на кнопках',
      'Баскычтарда жумшак чыкылдоо',
      'A soft click on buttons'
    ],
    'appearance': ['Оформление', 'Көрүнүш', 'Appearance'],
    'language': ['Язык', 'Тил', 'Language'],
    'theme': ['Тема', 'Тема', 'Theme'],
    'theme_system': ['Системная', 'Системалык', 'System'],
    'theme_light': ['Светлая', 'Жарык', 'Light'],
    'theme_dark': ['Тёмная', 'Караңгы', 'Dark'],
    'theme_sand': ['Песочная', 'Кум түстүү', 'Sand'],
    'vibe': ['Вайб', 'Маанай', 'Vibe'],
    'vibeSub': [
      'Живой фон под настроение. Коснитесь экрана — подует ветер',
      'Маанайга жараша тирүү фон. Экранга тийиңиз — шамал согот',
      'A living backdrop. Tap the screen for a gust of wind'
    ],
    'vibe_off': ['Выкл', 'Өчүк', 'Off'],
    'vibe_auto': ['Авто', 'Авто', 'Auto'],
    'vibe_autumn': ['Осень', 'Күз', 'Autumn'],
    'vibe_winter': ['Зима', 'Кыш', 'Winter'],
    'vibe_spring': ['Весна', 'Жаз', 'Spring'],
    'vibe_summer': ['Лето', 'Жай', 'Summer'],
    'vibe_night': ['Ночь', 'Түн', 'Night'],
    'about': ['О приложении', 'Тиркеме жөнүндө', 'About'],
    'version': ['Версия', 'Версия', 'Version'],
    'privacy': ['Конфиденциальность', 'Купуялык', 'Privacy'],
    'logout': ['Выйти', 'Чыгуу', 'Log out'],
    'logoutQ': ['Выйти из аккаунта?', 'Аккаунттан чыгасызбы?', 'Log out?'],
    'logoutSub': [
      'Вы сможете войти снова в любой момент',
      'Каалаган убакта кайра кире аласыз',
      'You can sign back in anytime'
    ],
  };
}

extension L10nX on BuildContext {
  String tr(String key) => AppStrings.get(
      Localizations.maybeLocaleOf(this) ?? const Locale('ru'), key);
}
