# Mirac Wicked HUD Kurulum

Bu belge Mirac Wicked HUD `1.2.0` içindir.

## 1. Gereksinimler

- Qbox kullanan FiveM sunucusu
- `qbx_core`
- `ox_lib`

Doğrulanan geliştirme tabanı qbx_core 1.23.0 ve ox_lib 3.39.0'dır. HUD bu
dependency'leri paketlemez.

## 2. Resource klasörü

Resource'u şu yola yerleştir:

```text
resources/[local]/mirac_wicked_hud/
```

Klasör adını değiştirmemen önerilir. Dahili network event isimleri resource
adına uyum sağlar; dokümante edilen export'lar ve entegrasyon örnekleri
varsayılan olarak `mirac_wicked_hud` adını kullanır.

## 3. Başlatma sırası

```cfg
setr ox:locale "tr"

ensure ox_lib
ensure qbx_core
ensure mirac_wicked_hud
```

HUD'u ox_lib veya qbx_core'dan önce başlatma.

## 4. Dil

```cfg
setr ox:locale "tr"
```

Dahil edilen diller: `tr`, `en`.

## 5. Yakıt adaptörü

Varsayılan:

```lua
Config.FuelSystem = 'native'
```

Seçenekler:

- `native`: GTA yakıt seviyesini okur
- `statebag`: `Config.FuelStateBag` anahtarını okur
- `export`: `Config.FuelResource` / `Config.FuelExport` çağrısını yapar
- `custom`: `bridge/fuel/client.lua` içinde özel adaptör kullanır

Harici kaynak değer döndürmezse adaptör state bag/native değere geri döner.

## 6. Ses sistemi

Varsayılan:

```lua
Config.VoiceSystem = 'auto'
```

`auto`, çalışıyorsa pma-voice kullanır; yoksa hem GTAV Legacy hem GTAV
Enhanced tarafından desteklenen network talking state'e geçer.

### GTAV Enhanced

Yeni server-owned ses altyapısını `server.cfg` içinde etkinleştir:

```cfg
voice_internal
```

HUD, eski `setr sv_mumble true` uyumluluk katmanına ihtiyaç duymaz ve ses
kanallarını yönetmez.

Enhanced API client tarafına proximity indeksi vermediğinden, ses resource'un
seçilen HUD seviyesini (`1` fısıltı, `2` normal, `3` bağırma) şu adaptörlerden
biriyle aktarabilir:

```lua
-- Server: replicated state bag (önerilen)
Player(source).state:set('miracVoiceMode', 2, true)

-- Client: yerel event
TriggerEvent('mirac_wicked_hud:voice:setMode', 2)

-- Client: export
exports.mirac_wicked_hud:setVoiceMode(2)
```

State bag anahtarı `Config.VoiceModeStateBag` ile değiştirilebilir.

### Manuel ses modu

`Config.VoiceSystem` seçenekleri:

- `auto`: pma-voice algılar, yoksa Enhanced/native konuşma durumunu kullanır
- `pma-voice`: pma-voice proximity state ve event'lerini kullanır
- `enhanced`: network talking state + HUD proximity adaptörünü kullanır
- `native`: network talking state + HUD proximity adaptörünü kullanır
- `custom`: konuşma durumu native, proximity seviyesi export/event ile sağlanır

## 7. HUD ayarları

Şu görsel tercihler client KVP'de saklanır:

- açık/kapalı
- normal/minimal mod
- konum
- renk paleti
- şeffaflık

SQL tablosu veya migration gerekmez.

Oyuncu bu yerel görsel ayarları şu komutla sıfırlayabilir:

```text
/hudreset
/hudyenile
```

Komut can, zırh, stamina, tokluk, susuzluk veya başka bir oynanış/framework
değerine yazmaz.

## 8. Minimap

```lua
Config.Minimap.mode = 'vehicle' -- vehicle | always | never
Config.Minimap.hideNativeVitals = true
```

Resource durduğunda native radar ve health/armour HUD durumu geri yüklenir.

## 9. Nitro

```lua
Config.Nitro.enabled = true
Config.Nitro.stateBags = { 'nitro', 'nitroLevel', 'nos', 'nitrous' }
```

HUD listedeki ilk geçerli state bag değerini yüzde 0-100 aralığında gösterir.

## 10. Güncelleme

1. Özelleştirdiysen `config/` klasörünü yedekle.
2. Eski `mirac_wicked_hud` klasörünü yeni sürümle değiştir.
3. Yerel config değişikliklerini yeni alanları koruyarak yeniden uygula.
4. Yalnızca HUD değiştiyse `restart mirac_wicked_hud` genellikle yeterlidir.
5. ox_lib güncellendiyse dependency'leri yeniden başlat veya temiz server
   restart yap.

`1.0.0` sürümünden güncellerken `Config.VoiceSystem` ve
`Config.VoiceModeStateBag` alanlarını `config/shared.lua` içine eklemeyi unutma.

## 11. Sorun giderme

### `Dependency ox_lib/qbx_core failed to load`

Dependency'nin HUD'dan önce sorunsuz başladığını doğrula.

### Karakter seçiminden sonra HUD açılmıyor

Qbox PlayerData'nın yüklendiğini ve qbx_core sürümünde
`@qbx_core/modules/playerdata.lua` bulunduğunu doğrula.

### Enhanced'ta konuşma ikonu çalışıyor fakat seviye değişmiyor

Yeni ses API'si proximity seviyesini HUD'a otomatik vermez. Ses resource'una
`miracVoiceMode` state bag, local event veya export adaptörünü ekle.

### Yakıt yanlış görünüyor

Doğru `Config.FuelSystem` adaptörünü seç veya doğrulama için önce `native`
kullan.

### `lib.notify` Wicked HUD tasarımında görünmüyor

Doğrudan ox_lib çağrıları ox_lib'e aittir. Başka bir resource'un Wicked HUD
üzerinden bildirim göstermesi için HUD export/event'ini kullan veya bridge
event yapılandır.
