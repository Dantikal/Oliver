import 'dart:math';

import '../../features/auth/domain/user.dart';
import '../../features/catalog/domain/comment.dart';
import '../../features/catalog/domain/product.dart';
import '../../features/catalog/domain/reference.dart';
import '../../features/chats/domain/chat.dart';
import '../../features/notifications/domain/notification.dart';
import '../network/api_exception.dart';
import '../pagination/paged.dart';

/// In-memory «backend» для разработки UI без сервера.
/// Включается флагом AppConfig.useMock (по умолчанию true).
class MockDb {
  MockDb._() {
    _seed();
  }
  static final MockDb instance = MockDb._();

  final _rnd = Random(7);
  static const meId = 'u1';
  static const otpCode = '123456';

  late User me;
  final users = <String, User>{};
  final categories = <ProductCategory>[];
  final regions = <Region>[];
  final cities = <String, List<City>>{};
  final products = <Product>[];
  final favorites = <String>{};
  final comments = <String, List<Comment>>{};
  final chats = <ChatSummary>[];
  final messages = <String, List<Message>>{};
  final notifications = <AppNotification>[];
  int newLikes = 3;
  int _seq = 1000;

  String nextId(String prefix) => '$prefix${_seq++}';

  Future<void> delay([int min = 350, int max = 850]) =>
      Future.delayed(Duration(milliseconds: min + _rnd.nextInt(max - min)));

  PageResult<T> page<T>(List<T> all, int page, int size) {
    final from = page * size;
    final items = from >= all.length
        ? <T>[]
        : all.sublist(from, min(from + size, all.length));
    return PageResult(items: items, total: all.length, page: page, size: size);
  }

  Never notFound() =>
      throw const ApiException(status: 404, message: 'Не найдено');

  static String img(String id, {int w = 900}) =>
      'https://images.unsplash.com/photo-$id?w=$w&q=80&auto=format&fit=crop';
  static String face(String id) =>
      'https://images.unsplash.com/photo-$id?w=240&h=240&q=80&fit=crop&crop=faces';

  ProductCategory? categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
      for (final s in c.children) {
        if (s.id == id) return s;
      }
    }
    return null;
  }

  String rootCategoryOf(String id) {
    for (final c in categories) {
      if (c.id == id || c.children.any((s) => s.id == id)) return c.id;
    }
    return id;
  }

  City? cityById(String id) {
    for (final l in cities.values) {
      for (final c in l) {
        if (c.id == id) return c;
      }
    }
    return null;
  }

  String regionOfCity(String cityId) =>
      cities.entries.firstWhere((e) => e.value.any((c) => c.id == cityId)).key;

  Product withFav(Product p) => Product(
        id: p.id,
        title: p.title,
        description: p.description,
        price: p.price,
        currency: p.currency,
        categoryId: p.categoryId,
        categoryName: p.categoryName,
        regionId: p.regionId,
        regionName: p.regionName,
        cityId: p.cityId,
        cityName: p.cityName,
        phone: p.phone,
        whatsappLink: p.whatsappLink,
        telegramLink: p.telegramLink,
        media: p.media,
        seller: p.seller,
        createdAt: p.createdAt,
        isFavorite: favorites.contains(p.id),
        commentsCount: _countComments(p.id),
        viewsCount: p.viewsCount,
        likesCount: p.likesCount,
        status: p.status,
      );

  int _countComments(String productId) => (comments[productId] ?? const [])
      .fold(0, (s, c) => s + 1 + c.totalReplies);

  // ---------------------------------------------------------------- seed

  void _seed() {
    final now = DateTime.now();
    final people = [
      ('u1', 'Азамат Токтогулов', '1507003211169-0a1dd7228f2d'),
      ('u2', 'Айпери Жумабекова', '1494790108377-be9c29b29330'),
      ('u3', 'Бакыт Исаков', '1506794778202-cad84cf45f1d'),
      ('u4', 'Айгерим Садыкова', '1544005313-94ddf0286df2'),
      ('u5', 'Нурлан Абдыкадыров', '1527980965255-d3b416303d12'),
      ('u6', 'Жылдыз Осмонова', '1488426862026-3ee34a7d66df'),
      ('u7', 'Эрлан Мамытов', '1531427186611-ecfd6d936c79'),
      ('u8', 'Сезим Касымова', '1534528741775-53994a69daeb'),
      ('u9', 'Тимур Бейшеев', '1500648767791-00dcc994a43e'),
      ('u10', 'Мээрим Акматова', '1438761681033-6461ffad8d80'),
    ];
    for (final (id, name, photo) in people) {
      users[id] = User(
        id: id,
        fullName: name,
        avatarUrl: face(photo),
        email: id == meId ? 'azamat@oliver.kg' : null,
        phone: id == meId
            ? '+996700123456'
            : '+99655${_rnd.nextInt(8999999) + 1000000}',
        role: 'USER',
        createdAt: now.subtract(Duration(days: 120 + _rnd.nextInt(900))),
      );
    }
    me = users[meId]!;

    categories.addAll(const [
      ProductCategory(id: 'c10', name: 'Отдам даром', icon: 'gift', children: [
        ProductCategory(id: 'c10-1', name: 'Вещи и одежда'),
        ProductCategory(id: 'c10-2', name: 'Мебель и дом'),
        ProductCategory(id: 'c10-3', name: 'Животные'),
        ProductCategory(id: 'c10-4', name: 'Растения'),
        ProductCategory(id: 'c10-5', name: 'Детское'),
      ]),
      ProductCategory(id: 'c1', name: 'Электроника', icon: 'phone', children: [
        ProductCategory(id: 'c1-1', name: 'Телефоны'),
        ProductCategory(id: 'c1-2', name: 'Ноутбуки'),
        ProductCategory(id: 'c1-3', name: 'Аудио'),
        ProductCategory(id: 'c1-4', name: 'Фото и видео'),
        ProductCategory(id: 'c1-5', name: 'Игры и приставки'),
      ]),
      ProductCategory(id: 'c2', name: 'Транспорт', icon: 'car', children: [
        ProductCategory(id: 'c2-1', name: 'Легковые'),
        ProductCategory(id: 'c2-2', name: 'Мото'),
        ProductCategory(id: 'c2-3', name: 'Велосипеды'),
      ]),
      ProductCategory(id: 'c3', name: 'Недвижимость', icon: 'home', children: [
        ProductCategory(id: 'c3-1', name: 'Квартиры'),
        ProductCategory(id: 'c3-2', name: 'Дома'),
      ]),
      ProductCategory(
          id: 'c9',
          name: 'Мал базар',
          icon: 'livestock',
          children: [
            ProductCategory(id: 'c9-1', name: 'КРС'),
            ProductCategory(id: 'c9-2', name: 'Лошади'),
            ProductCategory(id: 'c9-3', name: 'Бараны и овцы'),
            ProductCategory(id: 'c9-4', name: 'Козы'),
            ProductCategory(id: 'c9-5', name: 'Птица'),
            ProductCategory(id: 'c9-6', name: 'Корма'),
          ]),
      ProductCategory(id: 'c4', name: 'Одежда', icon: 'clothes', children: [
        ProductCategory(id: 'c4-1', name: 'Обувь'),
        ProductCategory(id: 'c4-2', name: 'Женская одежда'),
        ProductCategory(id: 'c4-3', name: 'Аксессуары'),
      ]),
      ProductCategory(
          id: 'c5',
          name: 'Дом и сад',
          icon: 'furniture',
          children: [
            ProductCategory(id: 'c5-1', name: 'Мебель'),
            ProductCategory(id: 'c5-2', name: 'Декор'),
            ProductCategory(id: 'c5-3', name: 'Растения'),
          ]),
      ProductCategory(id: 'c6', name: 'Хобби', icon: 'hobby', children: [
        ProductCategory(id: 'c6-1', name: 'Музыка'),
        ProductCategory(id: 'c6-2', name: 'Спорт'),
      ]),
      ProductCategory(id: 'c7', name: 'Животные', icon: 'pets', children: [
        ProductCategory(id: 'c7-1', name: 'Собаки'),
        ProductCategory(id: 'c7-2', name: 'Кошки'),
      ]),
      ProductCategory(id: 'c8', name: 'Услуги', icon: 'services'),
    ]);

    final geo = <(String, String, List<String>)>[
      ('r0', 'Бишкек', ['Бишкек']),
      ('r00', 'Ош', ['Ош']),
      ('r1', 'Чуйская обл.', ['Токмок', 'Кант', 'Кара-Балта', 'Сокулук']),
      ('r2', 'Иссык-Кульская обл.', ['Каракол', 'Чолпон-Ата', 'Балыкчы']),
      ('r3', 'Ошская обл.', ['Узген', 'Кара-Суу', 'Ноокат']),
      ('r4', 'Джалал-Абадская обл.', ['Джалал-Абад', 'Таш-Кумыр', 'Кербен']),
      ('r5', 'Нарынская обл.', ['Нарын', 'Кочкор', 'Ат-Башы']),
      ('r6', 'Таласская обл.', ['Талас', 'Кара-Буура']),
      ('r7', 'Баткенская обл.', ['Баткен', 'Кызыл-Кия', 'Сулюкта']),
    ];
    var ci = 0;
    for (final (id, name, cs) in geo) {
      regions.add(Region(id: id, name: name));
      cities[id] = [for (final c in cs) City(id: 'ct${ci++}', name: c)];
    }

    // (заголовок, категория, цена, валюта, фото, описание)
    final items = <(String, String, double?, Currency, List<String>, String)>[
      (
        'Корова голштинская, 4 года, стельная',
        'c9-1',
        145000,
        Currency.kgs,
        ['1570042225831-d98fa7577f1e', '1500595046743-cd271d694d30'],
        'Даёт 18–20 л молока в день, спокойная, привита. Отёл ожидается через 2 месяца. Все документы и ветпаспорт на руках. Смотреть в Сокулуке.'
      ),
      (
        'Бычок на откорм, 1.5 года',
        'c9-1',
        85000,
        Currency.kgs,
        ['1527153857715-3908f2bae5e8'],
        'Вес около 320 кг, здоровый, привит от ящура. Кормили сеном и ячменём. Возможна доставка по Чуйской области.'
      ),
      (
        'Жеребец, 5 лет, кыргызская порода',
        'c9-2',
        220000,
        Currency.kgs,
        ['1553284965-83fd3e82fa5a'],
        'Выносливый, объезженный, ходит под седлом. Подойдёт для кок-бору и дальних перегонов. Без вредных привычек, ковали месяц назад.'
      ),
      (
        'Бараны гиссарские, 10 голов',
        'c9-3',
        18000,
        Currency.kgs,
        ['1484557985045-edf25e08da73', '1500595046743-cd271d694d30'],
        'Цена за голову. Возраст 8–10 месяцев, упитанные, к Курман айту в самый раз. Можно забрать всех сразу — сделаю скидку.'
      ),
      (
        'Козы зааненские, дойные',
        'c9-4',
        15000,
        Currency.kgs,
        ['1524024973431-2ad916746881'],
        'Две козы, 2 и 3 года, дают по 3 л молока. Молоко без запаха. Продаю из-за переезда.'
      ),
      (
        'Куры-несушки, 20 шт.',
        'c9-5',
        600,
        Currency.kgs,
        ['1548550023-2bdb3c5beed7', '1612170153139-6f881ff067e0'],
        'Цена за одну курицу. Порода ломан браун, несутся каждый день. Петух в подарок при покупке от 10 штук.'
      ),
      (
        'iPhone 15 Pro 256GB, Natural Titanium',
        'c1-1',
        98000,
        Currency.kgs,
        ['1695048133142-1a20484d2569', '1592750475338-74b7b21085ab'],
        'Состояние идеальное, АКБ 97%. Полный комплект, коробка, чек. Без сколов и царапин, всегда в чехле и со стеклом. Возможен обмен с доплатой.'
      ),
      (
        'Toyota Camry 70, 2019',
        'c2-1',
        23500,
        Currency.usd,
        ['1621007947382-bb3c3994e3fb'],
        'Пробег 68 000 км, один хозяин, обслуживание у официального дилера. Кожаный салон, камера, Apple CarPlay. Растаможена, учёт KG.'
      ),
      (
        'MacBook Air M2 13", 16/512',
        'c1-2',
        1250,
        Currency.usd,
        ['1611186871348-b1ce696e52c9', '1517336714731-489689fd1ca8'],
        '89 циклов зарядки. Midnight. Покупал в Америке, гарантия Apple Care до конца года. Отдам с чехлом.'
      ),
      (
        '2-комн. квартира, 72 м², Джал',
        'c3-1',
        89000,
        Currency.usd,
        [
          '1502672260266-1c1ef2d93688',
          '1522708323590-d24dbb6b0267',
          '1586023492125-27b2c045efd7'
        ],
        'Элитка, 9/12 этаж, авторский ремонт, вся мебель и техника остаются. Красная книга, документы готовы. Рядом школа, парк и ТЦ.'
      ),
      (
        'Кроссовки Nike Air Zoom, 42 р.',
        'c4-1',
        6500,
        Currency.kgs,
        ['1542291026-7eec264c27ff'],
        'Оригинал, носил 2 раза — не подошёл размер. Коробка на месте.'
      ),
      (
        'Sony PlayStation 5 + 2 геймпада',
        'c1-5',
        42000,
        Currency.kgs,
        ['1606813907291-d86efa9b94db'],
        'Версия с дисководом. В комплекте 2 джойстика, зарядная станция и 5 дисков: FIFA 24, GTA V, Spider-Man 2, God of War, Mortal Kombat.'
      ),
      (
        'Щенки сибирского хаски',
        'c7-1',
        15000,
        Currency.kgs,
        ['1605568427561-40dd23c2acea'],
        'Голубоглазые, 2 месяца, привиты по возрасту, есть ветпаспорт. Родители с документами РКФ.'
      ),
      (
        'Велосипед Fixie, рама 54',
        'c2-3',
        null,
        Currency.negotiable,
        ['1485965120184-e220f721d03e', '1571068316344-75bc76f77890'],
        'Лёгкий городской сингл-спид. Новые покрышки и цепь. Рассмотрю обмен на шоссейник.'
      ),
      (
        'Диван «Velvet» изумрудный',
        'c5-1',
        38000,
        Currency.kgs,
        ['1555041469-a586c61ea9bc'],
        'Велюр, 220 см, раскладной механизм. Без животных, некурящая семья. Самовывоз из 7 мкр.'
      ),
      (
        'Наушники Beats Studio Pro',
        'c1-3',
        18500,
        Currency.kgs,
        ['1505740420928-5e560c06d30e'],
        'Шумоподавление, до 40 часов работы. Полный комплект, гарантия 6 мес.'
      ),
      (
        'Sony A7 III + объектив 28-70',
        'c1-4',
        1400,
        Currency.usd,
        ['1516035069371-29a1b244cc32'],
        'Пробег 18 тыс. кадров. В комплекте 2 аккумулятора, сумка и карта 128 GB.'
      ),
      (
        'Кожаная куртка Zara, M',
        'c4-2',
        4900,
        Currency.kgs,
        ['1551028719-00167b16eac5'],
        'Натуральная кожа, носила один сезон. Отличное состояние.'
      ),
      (
        'Акустическая гитара Yamaha F310',
        'c6-1',
        9000,
        Currency.kgs,
        ['1510915361894-db8b60106cb1'],
        'Отличный звук для начинающих. В подарок чехол, каподастр и медиаторы.'
      ),
      (
        'Ford Mustang GT 5.0, 2018',
        'c2-1',
        31000,
        Currency.usd,
        ['1494976388531-d1058494cdd8'],
        'V8, 460 л.с., выхлоп Borla. Без ДТП, свежее ТО.'
      ),
      (
        'Платье вечернее красное',
        'c4-2',
        7200,
        Currency.kgs,
        ['1595777457583-95e059d581b8'],
        'Размер S, шёлк, длина в пол. Надевала один раз на выпускной.'
      ),
      (
        'Дом 180 м² в Кок-Жаре',
        'c3-2',
        165000,
        Currency.usd,
        ['1568605114967-8130f3a36994', '1600585154340-be6161a56a0c'],
        'Двухэтажный дом, участок 6 соток, гараж на 2 машины, сауна. Центральные коммуникации.'
      ),
      (
        'Кот шотландский, ищет дом',
        'c7-2',
        null,
        Currency.negotiable,
        ['1514888286974-6c03e2ca1dba'],
        'Ласковый, приучен к лотку, 1 год. Отдадим в добрые руки с переноской и кормом.'
      ),
      (
        'Дрон DJI Phantom 4 Pro',
        'c1-4',
        85000,
        Currency.kgs,
        ['1473968512647-3e447244af8f'],
        '3 аккумулятора, кейс. Налёт 20 часов, без падений.'
      ),
      (
        'AirPods Pro 2 (USB-C)',
        'c1-3',
        16500,
        Currency.kgs,
        ['1600294037681-c80b4cb5b434'],
        'Новые, запечатанные. Привезли из Дубая.'
      ),
      (
        'Tesla Model 3 Long Range',
        'c2-1',
        29900,
        Currency.usd,
        ['1560958089-b8a1929cea89'],
        '2021 год, запас хода 520 км. Автопилот, белый салон. Зарядка в комплекте.'
      ),
      (
        'Nike Air Force 1 «Wheat»',
        'c4-1',
        8900,
        Currency.kgs,
        ['1549298916-b41d501d3772'],
        'Размер 43. Оригинал, новые.'
      ),
      (
        'Настольная лампа IKEA',
        'c5-2',
        1800,
        Currency.kgs,
        ['1507473885765-e6ed057f782c'],
        'Регулируемый плафон, тёплый свет. Почти новая.'
      ),
      (
        'Сумка Gucci Marmont',
        'c4-3',
        1100,
        Currency.usd,
        ['1548036328-c9fa89d128fa'],
        'Оригинал, есть чек и пыльник. Состояние отличное.'
      ),
      (
        'iPad Pro 11" M1 + Pencil',
        'c1-1',
        62000,
        Currency.kgs,
        ['1544244015-0df4b3ffc6b0'],
        '128 GB, Wi-Fi + Cellular. В комплекте Apple Pencil 2 и чехол Smart Folio.'
      ),
      (
        'Porsche 911 Carrera S',
        'c2-1',
        115000,
        Currency.usd,
        ['1503376780353-7e6692767b70'],
        'Мечта! Полная история обслуживания. Обмен не интересует.'
      ),
      (
        'Apple Watch Series 9, 45mm',
        'c1-3',
        28000,
        Currency.kgs,
        ['1546868871-7041f2a55e12'],
        'Midnight, LTE. Гарантия до весны.'
      ),
      (
        'Суккуленты в горшках',
        'c5-3',
        450,
        Currency.kgs,
        ['1485955900006-10f4d324d411'],
        'Большой выбор. Доставка по Бишкеку от 3 штук.'
      ),
      (
        'Электромотоцикл LiveWire',
        'c2-2',
        18000,
        Currency.usd,
        ['1558981403-c5f9899a28bc'],
        'Тихий и быстрый. Пробег 4 000 км.'
      ),
      (
        'Барный стул, 2 шт.',
        'c5-1',
        3200,
        Currency.kgs,
        ['1503602642458-232111445657'],
        'Массив бука. Цена за оба.'
      ),
      (
        'Ремонт квартир под ключ',
        'c8',
        null,
        Currency.negotiable,
        ['1600585154340-be6161a56a0c'],
        'Бригада с опытом 10+ лет. Дизайн-проект в подарок. Гарантия 2 года.'
      ),
      (
        'Кеды Vans Old Skool',
        'c4-1',
        3900,
        Currency.kgs,
        ['1525966222134-fcfa99b8ae77'],
        'Размеры 38–44, новые. Бордовые.'
      ),
      (
        'Smart TV LG OLED 55"',
        'c1-5',
        79000,
        Currency.kgs,
        ['1593359677879-a4bb92f829d1'],
        '4K 120 Гц, идеален для PS5. Пульт Magic.'
      ),
      (
        'Чехлы для iPhone, силикон MagSafe',
        'c1-1',
        1200,
        Currency.kgs,
        ['1592750475338-74b7b21085ab'],
        'Мягкий силикон, внутри микрофибра, магниты MagSafe. Есть на все модели с 12 по 16 Pro Max. Выберите модель и цвет при заказе — отправлю в день оплаты.'
      ),
      // Отдам даром.
      (
        'Котята в добрые руки',
        'c10-3',
        null,
        Currency.free,
        ['1514888286974-6c03e2ca1dba'],
        'Три котёнка, 2 месяца, едят сами, приучены к лотку. Отдадим только в любящую семью.'
      ),
      (
        'Отдам настольную лампу',
        'c10-2',
        null,
        Currency.free,
        ['1507473885765-e6ed057f782c'],
        'Рабочая, просто купили новую. Забрать в 12 мкр, сегодня-завтра.'
      ),
      (
        'Отростки суккулентов',
        'c10-4',
        null,
        Currency.free,
        ['1485955900006-10f4d324d411'],
        'Разрослись — делюсь бесплатно. Эхеверии и толстянка, можно с горшками.'
      ),
      (
        'Барные стулья, нужен ремонт',
        'c10-2',
        null,
        Currency.free,
        ['1503602642458-232111445657'],
        'Шатаются ножки, но массив крепкий. Отдам тому, кто умеет чинить. Самовывоз.'
      ),
      (
        'Гитара для начинающих',
        'c10-1',
        null,
        Currency.free,
        ['1510915361894-db8b60106cb1'],
        'Старая, но строит. Отдам ребёнку, который хочет учиться играть.'
      ),
    ];

    final sellers = users.keys.where((k) => k != meId).toList();
    final regionIds = cities.keys.toList();
    for (var i = 0; i < items.length; i++) {
      final (title, cat, price, cur, photos, desc) = items[i];
      final regionId =
          i % 3 == 0 ? 'r0' : regionIds[_rnd.nextInt(regionIds.length)];
      final city = cities[regionId]![_rnd.nextInt(cities[regionId]!.length)];
      final seller = i % 7 == 3 ? me : users[sellers[i % sellers.length]]!;
      final media = <MediaItem>[
        for (var k = 0; k < photos.length; k++)
          MediaItem(id: 'm$i-$k', url: img(photos[k]), type: MediaType.image),
        if (i == 1 || i == 7 || i == 13)
          MediaItem(
            id: 'm$i-v',
            url:
                'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
            type: MediaType.video,
            thumbnailUrl: img(photos.first),
          ),
      ];
      final category = categoryById(cat)!;
      products.add(Product(
        id: 'p${i + 1}',
        title: title,
        description: desc,
        price: price,
        currency: cur,
        categoryId: cat,
        categoryName: category.name,
        regionId: regionId,
        regionName: regions.firstWhere((r) => r.id == regionId).name,
        cityId: city.id,
        cityName: city.name,
        phone: seller.phone,
        whatsappLink: i.isEven
            ? 'https://wa.me/${seller.phone?.replaceAll('+', '')}'
            : null,
        telegramLink: i % 3 == 0 ? 'https://t.me/oliver_kg' : null,
        media: media,
        seller: seller,
        createdAt:
            now.subtract(Duration(minutes: 7 + i * 95 + _rnd.nextInt(60))),
        viewsCount: 40 + _rnd.nextInt(2400),
        likesCount: _rnd.nextInt(80),
        // Для кабинета продавца: одно моё объявление продано, одно в архиве.
        status: seller == me && i == 10
            ? ProductStatus.sold
            : seller == me && i == 17
                ? ProductStatus.archived
                : ProductStatus.active,
      ));
    }

    // Варианты товара: модель/цвет/размер — покупатель выбирает при заказе.
    const colors = [
      OptionValue(label: 'Чёрный', color: '#1C1C1E'),
      OptionValue(label: 'Белый', color: '#F2F2F2'),
      OptionValue(label: 'Красный', color: '#E5484D'),
      OptionValue(label: 'Синий', color: '#2F6FED'),
      OptionValue(label: 'Зелёный', color: '#2FA35A'),
      OptionValue(label: 'Розовый', color: '#F49AC1'),
      OptionValue(label: 'Фиолетовый', color: '#8E6CEF'),
    ];
    final variants = <String, List<ProductOption>>{
      'Чехлы для iPhone, силикон MagSafe': const [
        ProductOption(name: 'Модель', values: [
          OptionValue(label: 'iPhone 12'),
          OptionValue(label: 'iPhone 13'),
          OptionValue(label: 'iPhone 14'),
          OptionValue(label: 'iPhone 15'),
          OptionValue(label: 'iPhone 15 Pro'),
          OptionValue(label: 'iPhone 15 Pro Max'),
          OptionValue(label: 'iPhone 16'),
          OptionValue(label: 'iPhone 16 Pro Max'),
        ]),
        ProductOption(name: 'Цвет', kind: OptionKind.color, values: colors),
      ],
      'Кроссовки Nike Air Zoom, 42 р.': const [
        ProductOption(name: 'Размер', values: [
          OptionValue(label: '40'),
          OptionValue(label: '41'),
          OptionValue(label: '42'),
          OptionValue(label: '43'),
        ]),
      ],
      'Кеды Vans Old Skool': [
        const ProductOption(name: 'Размер', values: [
          OptionValue(label: '38'),
          OptionValue(label: '39'),
          OptionValue(label: '40'),
          OptionValue(label: '41'),
          OptionValue(label: '42'),
          OptionValue(label: '43'),
          OptionValue(label: '44'),
        ]),
        ProductOption(
            name: 'Цвет',
            kind: OptionKind.color,
            values: [colors[0], colors[1], colors[2]]),
      ],
      'AirPods Pro 2 (USB-C)': const [
        ProductOption(name: 'Комплект', values: [
          OptionValue(label: 'Только наушники'),
          OptionValue(label: '+ чехол'),
          OptionValue(label: '+ чехол и ремешок'),
        ]),
      ],
    };
    for (var i = 0; i < products.length; i++) {
      final o = variants[products[i].title];
      if (o != null) products[i] = products[i].copyWith(options: o);
    }

    favorites.addAll(['p2', 'p4', 'p6', 'p11', 'p20']);

    // Комментарии
    Comment c(String id, String uid, String text, int minsAgo,
            {int likes = 0,
            bool liked = false,
            String? parent,
            List<Comment> replies = const []}) =>
        Comment(
          id: id,
          userId: uid,
          fullName: users[uid]!.fullName,
          avatarUrl: users[uid]!.avatarUrl,
          text: text,
          likesCount: likes,
          isLiked: liked,
          parentCommentId: parent,
          createdAt: now.subtract(Duration(minutes: minsAgo)),
          replies: replies,
        );

    for (final p in products) {
      final sid = p.seller.id;
      final a = sellers[(p.id.hashCode) % sellers.length];
      final b = sellers[(p.id.hashCode + 3) % sellers.length];
      comments[p.id] = [
        c('${p.id}-c1', a, 'Здравствуйте! Ещё актуально? Торг уместен?', 300,
            likes: 4,
            replies: [
              c(
                  '${p.id}-c1r1',
                  sid,
                  'Добрый день! Да, актуально. Небольшой торг при осмотре 🙌',
                  280,
                  likes: 2,
                  parent: '${p.id}-c1',
                  replies: [
                    c('${p.id}-c1r1r1', a,
                        'Отлично, завтра после обеда удобно?', 260,
                        parent: '${p.id}-c1r1'),
                  ]),
            ]),
        c('${p.id}-c2', b, 'Есть доставка в регионы?', 190, likes: 1),
        c('${p.id}-c3', meId == sid ? a : meId,
            'Сохранил в избранное, очень круто выглядит 🔥', 45,
            likes: 7, liked: true),
        for (var k = 0; k < 14; k++)
          c(
              '${p.id}-x$k',
              sellers[(k + 2) % sellers.length],
              [
                'Цена хорошая 👍',
                'Можно ещё фото?',
                'Где можно посмотреть?',
                'В каком состоянии?',
                'Обмен рассматриваете?'
              ][k % 5],
              2000 + k * 120,
              likes: _rnd.nextInt(5)),
      ];
    }

    // Чаты
    final chatSeeds = [
      (
        'u2',
        'p1',
        [
          'Здравствуйте! iPhone ещё продаётся?',
          'Да, конечно 😊',
          'А за 92 отдадите?'
        ],
        2,
        4
      ),
      (
        'u3',
        'p2',
        [
          'Добрый вечер, по Камри — можно сегодня посмотреть?',
          'Можно, после 19:00 на Южной магистрали'
        ],
        0,
        35
      ),
      (
        'u4',
        'p9',
        ['Диван ещё в наличии?', 'Да! Самовывоз', 'Супер, беру 🙌'],
        1,
        120
      ),
      (
        'u5',
        'p6',
        ['PS5 с какой прошивкой?', 'Последняя, всё лицензионное'],
        0,
        60 * 26
      ),
      ('u6', 'p15', ['Платье супер! Есть размер M?'], 1, 60 * 30),
      (
        'u7',
        null,
        ['Салам! Видел ваше объявление, давайте созвонимся'],
        0,
        60 * 72
      ),
    ];
    for (final (peer, productId, texts, unread, minsAgo) in chatSeeds) {
      final chatId = 'ch_$peer';
      final p = productId == null
          ? null
          : products.firstWhere((x) => x.id == productId);
      final list = <Message>[];
      for (var k = 0; k < texts.length; k++) {
        final mine = k.isOdd;
        list.add(Message(
          id: '${chatId}_m$k',
          chatId: chatId,
          senderId: mine ? meId : peer,
          type: MessageType.text,
          content: texts[k],
          createdAt:
              now.subtract(Duration(minutes: minsAgo + (texts.length - k) * 3)),
          status: MessageStatus.read,
        ));
      }
      if (peer == 'u2') {
        list.insert(
            1,
            Message(
              id: '${chatId}_img',
              chatId: chatId,
              senderId: peer,
              type: MessageType.image,
              content: '',
              mediaUrl: img('1592750475338-74b7b21085ab', w: 600),
              createdAt: now.subtract(Duration(minutes: minsAgo + 11)),
            ));
      }
      messages[chatId] = list.reversed.toList(); // newest first
      chats.add(ChatSummary(
        chatId: chatId,
        peer: users[peer]!,
        lastMessage: messages[chatId]!.first,
        unreadCount: unread,
        updatedAt: messages[chatId]!.first.createdAt,
        isOnline: peer == 'u2' || peer == 'u4',
        productId: p?.id,
        productTitle: p?.title,
        productImage: p?.coverUrl,
      ));
    }

    final mine = products.where((p) => p.seller.id == meId).toList();
    notifications.addAll([
      for (var k = 0; k < 12; k++)
        AppNotification(
          id: 'n$k',
          type: k % 4 == 1
              ? NotificationType.comment
              : (k % 4 == 3 ? NotificationType.system : NotificationType.like),
          actorName: users[sellers[k % sellers.length]]!.fullName,
          actorAvatar: users[sellers[k % sellers.length]]!.avatarUrl,
          productId: mine[k % mine.length].id,
          productImage: mine[k % mine.length].coverUrl,
          text: k % 4 == 3
              ? 'Ваше объявление «${mine[k % mine.length].title}» набрало 100 просмотров 🎉'
              : (k % 4 == 1
                  ? 'прокомментировал(а) «${mine[k % mine.length].title}»: «Ещё актуально?»'
                  : 'добавил(а) в избранное «${mine[k % mine.length].title}»'),
          createdAt: now.subtract(Duration(minutes: 12 + k * 170)),
          isRead: k > 2,
        ),
    ]);
  }
}
