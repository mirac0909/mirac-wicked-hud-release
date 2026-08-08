# Mirac Wicked HUD

**Qbox** ve **ox_lib** için hazırlanmış açık kaynak FiveM HUD resource'u.
Framework işlemlerini bridge katmanında tutar, karakter ve başlangıç durum
verilerini Qbox'tan güvenli biçimde alır, görsel tercihleri client KVP'de
saklar ve GTAV Legacy ile GTAV Enhanced ses sistemlerini destekler.

## Dağıtım bilgisi

- Resource klasörü: `mirac_wicked_hud`
- Sürüm: `2.0.0-beta.1`
- Lisans: MIT
- Doğrulanan geliştirme tabanı: qbx_core 1.23.0, ox_lib 3.39.0

## Özellikler

- Eski QBCore core object kullanmadan Qbox PlayerData entegrasyonu
- ox_lib callback, keybind, locale, cache ve notification kullanımı
- Server-authoritative başlangıç karakter ve metadata verisi
- Can, zırh, stamina, tokluk ve susuzluk HUD'u
- Normal ve minimal gösterim; kritik değerleri otomatik açığa çıkarma
- Hız, vites, yakıt, motor ve opsiyonel nitro araç HUD'u
- Araçta / sürekli / kapalı minimap seçenekleri
- Native, statebag, export ve custom yakıt adaptörleri
- `sv_mumble` gerektirmeyen GTAV Enhanced ses göstergesi
- Otomatik pma-voice algılama ve üç kademeli ses mesafesi adaptörü
- 10 renk paleti ve yüzde 40-100 global HUD şeffaflığı
- Sağ üst, sol üst ve sağ alt yerleşimler
- GTA safe-zone uyumlu kenar boşlukları
- NUI hazır olma kuyruğu ve değişmeyen veriyi tekrar göndermeyen patch sistemi
- SQL gerektirmeyen client KVP ayar saklama
- Türkçe ve İngilizce locale
- Oyuncuya ait yerel görsel HUD sıfırlama komutu
- Resource restart ve karakter değişiminde güvenli temizlik

## Zorunlu dependency

- `qbx_core`
- `ox_lib`

HUD kendi başına `ox_inventory`, `ox_target`, SQL tablosu, pma-voice veya
harici bir yakıt resource'u zorunlu tutmaz.

## Hızlı kurulum

Resource'u `resources/[local]/mirac_wicked_hud` yoluna koy ve dependency'lerden
sonra başlat:

```cfg
setr ox:locale "tr"
ensure ox_lib
ensure qbx_core
ensure mirac_wicked_hud
```

GTAV Enhanced kullanıyorsan yeni ses sunucusunu da etkinleştir:

```cfg
voice_internal
```

Ayrıntılı kurulum için [INSTALL_TR.md](INSTALL_TR.md) dosyasına bak.

## Oyuncu komutları

| Komut | Açıklama |
| --- | --- |
| `/hud` | HUD görünürlüğünü açar/kapatır |
| `/hudayar` / `/hudsettings` | HUD ayar menüsünü açar |
| `/hudminimal` | Normal/minimal mod arasında geçiş yapar |
| `/hudrace` / `/hudyaris` | Normal araç HUD'ı ile yarış kokpiti arasında geçiş yapar |
| `/hudkonum` / `/hudposition [top-right/top-left/bottom-right]` | Konumu seçer veya sıradaki konuma geçer |
| `/hudreset` | Oyuncunun yerel görsel HUD ayarlarını sıfırlar |
| `/hudyenile` / `/hudrefresh` | Kayıtlı ayarları değiştirmeden yerel HUD görünümünü yeniden kurar |

`/hudreset`; görünürlük, normal/minimal mod, araç HUD görünümü, konum, palet ve şeffaflığı
`Config.DefaultSettings` değerlerine döndürür. Can, zırh, stamina, tokluk,
susuzluk, citizen ID veya başka bir framework/oynanış değerini değiştirmez.

Varsayılan `F10` görünürlük ve `TAB` durum ayrıntısı tuşları
`config/shared.lua` içinden değiştirilebilir.

## Export'lar

```lua
exports.mirac_wicked_hud:getHudPosition()
exports.mirac_wicked_hud:getHudPalette()
exports.mirac_wicked_hud:setHudPalette('emerald')
exports.mirac_wicked_hud:getHudOpacity()
exports.mirac_wicked_hud:setHudOpacity(85)
exports.mirac_wicked_hud:getHudLayoutMetrics()
exports.mirac_wicked_hud:isHudVisible()
exports.mirac_wicked_hud:setHudVisible(true)
exports.mirac_wicked_hud:getState()
exports.mirac_wicked_hud:setIdentityIds({
    temporaryId = 12,
    permanentId = 10042
})

-- Enhanced/native/custom: 1 fısıltı, 2 normal, 3 bağırma
exports.mirac_wicked_hud:setVoiceMode(2)
exports.mirac_wicked_hud:setSeatbelt(true)
exports.mirac_wicked_hud:isSeatbeltOn()
exports.mirac_wicked_hud:playNitroSound('start') -- start veya empty
exports.mirac_wicked_hud:playGearShiftSound('up') -- up veya down

exports.mirac_wicked_hud:notify({
    id = 'job-status',
    title = 'Bilgilendirme',
    description = 'Örnek bildirim',
    type = 'inform',
    duration = 3000
})
exports.mirac_wicked_hud:showTextUI('door', '[E] Etkileşim', {
    icon = 'hand',
    iconColor = '#60a5fa'
})
exports.mirac_wicked_hud:hideTextUI('door')
exports.mirac_wicked_hud:isTextUIOpen('door')
```

Bildirim alanları `id`, `title`, `description`, `type`, `duration`, `icon`,
`iconColor` ve `restartDuration` değerleridir. Desteklenen türler `inform`,
`info`, `success`, `warning` ve `error` değerleridir. Kimlikler çağıran
resource adına göre otomatik ayrılır; aynı kimlik tekrar kullanıldığında kart
yerinde güncellenir.

## Event'ler

Yerel bildirim:

```lua
TriggerEvent('mirac_wicked_hud:notify', {
    title = 'Bilgilendirme',
    description = 'Örnek',
    type = 'inform'
})

-- Server tarafında yalnız hedef oyuncuya gönderir.
exports.mirac_wicked_hud:notifyPlayer(source, {
    title = 'Sunucu',
    description = 'Hedefli mesaj',
    type = 'success'
})
```

Qbox maaş callback'i opsiyonel olarak aynı export'u çağırabilir:

```lua
if GetResourceState('mirac_wicked_hud') == 'started' then
    exports.mirac_wicked_hud:notifyPlayer(source, {
        id = 'paycheck',
        title = 'Maaş',
        description = message,
        type = 'success',
        duration = 6000
    })
end
```

Bu yalnız entegrasyon örneğidir; qbx_core dosyalarının değiştirilmesi HUD için
zorunlu değildir.

HUD hazır olduğunda:

```lua
AddEventHandler('mirac_wicked_hud:ready', function(initialData)
    -- Aktif karakter için HUD hazır.
end)
```

Enhanced/native/custom ses mesafesi:

```lua
TriggerEvent('mirac_wicked_hud:voice:setMode', 2)
```

## GTAV Legacy ve Enhanced ses desteği

Varsayılan `Config.VoiceSystem = 'auto'`, çalışıyorsa pma-voice kullanır.
pma-voice yoksa hem Legacy hem Enhanced tarafından desteklenen
`NetworkIsPlayerTalking` durumuna geçer.

Enhanced'ın yeni API'si ses kanallarını server tarafında yönetir ve client'a
bir proximity indeksi vermez. Ses resource'un seçilen seviyeyi state bag ile
HUD'a aktarabilir:

```lua
Player(source).state:set('miracVoiceMode', 2, true)
```

State bag anahtarı `Config.VoiceModeStateBag` ile değiştirilebilir. HUD ses
kanalı oluşturmaz, oyuncuyu kanala eklemez ve kanal üyeliğini yönetmez.

## Renk paletleri

`ocean`, `emerald`, `amethyst`, `amber`, `graphite`, `ruby`, `sakura`,
`frost`, `royal`, `lime`.

Paletler HUD yüzeylerini ve vurgu renklerini değiştirir. Can/zırh/stamina/
tokluk/susuzluk ile kritik uyarı renkleri semantik olarak sabit kalır.

## ox_lib sınırı

HUD standart ox_lib kurulumu ile çalışır ve müşterinin ox_lib dosyalarını
değiştirmez. Wicked HUD bildirimleri ile TextUI doğrudan bu resource içinde
gösterilir. `lib.notify`, `lib.showTextUI`, dialog, progress ve context menu
çağrıları müşterinin kendi ox_lib tasarımını kullanmaya devam eder.

## Yapılandırma

- `config/shared.lua`: bileşenler, metadata, tuşlar, hız birimi, ses, yakıt,
  nitro, minimap, safe-zone ve varsayılan görsel ayarlar
- `config/client.lua`: güncelleme aralıkları, NUI debug, geliştirme test API'si ve pause davranışı
- `config/server.lua`: callback throttle/cache ve log ayarları
- `bridge/`: Qbox, ses ve yakıt entegrasyonları

`Config.Notifications`; HUD'ın dahili bildirimlerini, varsayılan süreyi,
görünürlük davranışını, teknik güvenlik sınırını ve QB/ESX format
dönüştürücülerini yönetir. Başka scriptlerin event'leri
`bridgeEvents` listesine eklenebilir. Bu işlem eski notification handler'ını
otomatik kapatmaz.

TextUI aynı anda tek kayıt gösterir. Son açılan kayıt aktif olur; kapatıldığında
önceki geçerli kayıt geri gelir. TextUI ve notification kimlikleri resource
bazında ayrılır.

## Nitro ve emniyet kemeri

Yapılandırılmış nitro state bag'lerinden biri araçta varsa HUD nitro yüzdesini
gösterir. Nitro state bag'i yoksa aynı alan desteklenen araçlarda emniyet
kemeri göstergesine dönüşür. Dahili kemer sistemi `Config.Seatbelt.builtIn`
ile kapatılabilir; harici scriptler state bag, event veya export kullanabilir.

Strict state bag modu açık sunucularda nitro ve kemer state bag değerleri
server tarafından yazılmalıdır. Motosiklet, bisiklet, tekne, uçak ve trenlerde
kemer fallback göstergesi açılmaz.

`Config.Nitro`, `Config.Seatbelt`, `Config.GearShiftSound` ve
`Config.VehicleWarnings` bölümleri custom ses yolu ve ses seviyelerini
yönetir. Özel dosyalar `web/dist/sounds` altında `.ogg`, `.mp3` veya `.wav`
olarak tutulur. Ses ya da config değişikliğinden sonra HUD yeniden
başlatılmalıdır.

## Güvenlik modeli

Client; citizen ID veya Qbox metadata için güvenilir kabul edilmez. Başlangıç
verisi callback `source` üzerinden server tarafında çözülür. Yerel reset
yalnızca görsel KVP değerlerini temizler. NUI action/değerleri doğrulanır ve
strict NUI callback modu açıktır.

## Performans modeli

Framework metadata değişimleri event tabanlıdır. Araç telemetrisi yalnızca
gerektiğinde yüksek frekansta çalışır; gizli/boşta döngüler daha uzun bekler.
NUI'ya yalnızca değişen alanlar gönderilir.

## Lisans

MIT. Ayrıntı için [LICENSE](LICENSE).

Üçüncü taraf dependency'ler ana pakete dahil edilmez ve kendi lisanslarına
tabidir. Dahil edilen ses dosyaları için [ASSET_LICENSES.md](ASSET_LICENSES.md)
belgesine bak.
