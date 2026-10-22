const sampleNewsFeed = r'''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/">
<channel><title>Новости сервиса</title><link>https://t.me/example</link>
<item><guid>post-1</guid><title>Приложение для телевизора</title><link>https://t.me/example/1</link>
<pubDate>Wed, 21 Oct 2026 10:00:00 GMT</pubDate>
<description><![CDATA[<p>Новый интерфейс для управления с пульта.</p>]]></description></item>
<item><guid>post-2</guid><title>Обновление сервиса: больше удобства каждый день</title><link>https://t.me/example/2</link>
<pubDate>Thu, 22 Oct 2026 12:30:00 +0300</pubDate>
<description><![CDATA[<p>Короткое описание.</p>]]></description>
<content:encoded><![CDATA[<p>Мы подготовили <strong>обновление</strong>, которое делает приложение удобнее на всех устройствах.</p><p>Теперь следить за изменениями можно прямо на главной странице. Все важные публикации собраны в одном месте.</p><h3>Что изменилось</h3><ul><li>Удобная навигация с пульта телевизора.</li><li>Быстрое добавление подписки через телефон.</li><li>Более понятные уведомления об обновлениях.</li></ul><p>Настройки маршрутизации по правилам продолжают работать как прежде.</p><p><a href="https://t.me/example/2">Открыть публикацию в канале</a></p>]]></content:encoded></item>
<item><guid>post-2</guid><title>Duplicate</title><description>Duplicate content</description></item>
</channel></rss>
''';
