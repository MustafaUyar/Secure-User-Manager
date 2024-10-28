# JSON dosya yolu
$dosyaYolu = ".\bt.json"

# Kullanıcıdan anahtar kelimeyi al ve Base64 formatına çevir
$anahtarKelime = Read-Host "Lütfen şifreleme anahtarı olarak kullanacağınız kelimeyi girin"

# Anahtarın boyutunu ayarla (256-bit için 32 bayt)
$desiredLength = 32
$keyBytes = [System.Text.Encoding]::UTF8.GetBytes($anahtarKelime)

# Eğer anahtar daha kısa ise uygun boyuta doldur
if ($keyBytes.Length -lt $desiredLength) {
    $paddedKeyBytes = New-Object byte[] $desiredLength
    [Array]::Copy($keyBytes, $paddedKeyBytes, $keyBytes.Length)
    for ($i = $keyBytes.Length; $i -lt $desiredLength; $i++) {
        $paddedKeyBytes[$i] = 0
    }
    $keyBytes = $paddedKeyBytes
}

$sifrelemeAnahtari = [Convert]::ToBase64String($keyBytes)

# Şifreleme fonksiyonu
function Encrypt-Data {
    param (
        [string]$Data,
        [string]$Key
    )

    $Aes = New-Object System.Security.Cryptography.AesManaged
    $Aes.Key = [Convert]::FromBase64String($Key)
    $Aes.GenerateIV()
    $Aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
    $IV = [Convert]::ToBase64String($Aes.IV)

    $Encryptor = $Aes.CreateEncryptor()
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Data)
    $Encrypted = $Encryptor.TransformFinalBlock($Bytes, 0, $Bytes.Length)
    $EncryptedText = [Convert]::ToBase64String($Encrypted)

    return "${IV}:${EncryptedText}"
}

# Şifre çözme fonksiyonu
function Decrypt-Data {
    param (
        [string]$Data,
        [string]$Key
    )

    $Aes = New-Object System.Security.Cryptography.AesManaged
    $Aes.Key = [Convert]::FromBase64String($Key)
    $Aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
    $Parts = $Data -split ':'
    $Aes.IV = [Convert]::FromBase64String($Parts[0])

    $Decryptor = $Aes.CreateDecryptor()
    $Bytes = [Convert]::FromBase64String($Parts[1])
    $Decrypted = $Decryptor.TransformFinalBlock($Bytes, 0, $Bytes.Length)

    return [System.Text.Encoding]::UTF8.GetString($Decrypted)
}

# JSON dosyasını oku veya boş bir dizi oluştur
function VerileriOku {
    param (
        [string]$dosyaYolu,
        [string]$sifrelemeAnahtari
    )

    if (Test-Path -Path $dosyaYolu) {
        try {
            $encryptedData = Get-Content -Path $dosyaYolu -Raw
            $jsonData = Decrypt-Data -Data $encryptedData -Key $sifrelemeAnahtari
            $veriler = $jsonData | ConvertFrom-Json

            if ($null -eq $veriler) {
                return @()
            } elseif ($veriler -isnot [System.Collections.IEnumerable]) {
                return @($veriler)
            } else {
                return $veriler
            }
        }
        catch {
            Write-Output "Girmiş olduğunuz anahtar kelime hatalı. Lütfen doğru anahtar kelimeyi giriniz."
            Exit
        }
    } else {
        return @()
    }
}


# Güçlü şifre oluşturma fonksiyonu
function GuvenliSifreOlustur {
    param (
        [int]$uzunluk = 12
    )

    # Şifre için karakter kümeleri
    $buyukHarfler = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $kucukHarfler = "abcdefghijklmnopqrstuvwxyz"
    $rakamlar = "0123456789"
    $ozelKarakterler = "!@#$%^&*()-_=+[]{};:,.<>?"

    # Tüm karakterleri birleştir
    $tumKarakterler = $buyukHarfler + $kucukHarfler + $rakamlar + $ozelKarakterler

    # Şifreyi rastgele oluştur
    $sifre = -join (1..$uzunluk | ForEach-Object { $tumKarakterler[(Get-Random -Minimum 0 -Maximum $tumKarakterler.Length)] })

    return $sifre
}

# Güçlü şifreyle kullanıcı kaydetme fonksiyonu
function GuvenliKullaniciKaydet {
    param (
        [string]$hesap,
        [string]$email,
        [string]$dosyaYolu,
        [string]$sifrelemeAnahtari
    )

    # Şifre uzunluğunu kullanıcıdan alın ve sınırlandırın
    $uzunluk = Read-Host "Güçlü şifrenin uzunluğunu girin (8-20 arası)"

    # Kontrol et ve varsayılan uzunluk ayarla
    if (-not [int]::TryParse($uzunluk, [ref]$uzunluk) -or $uzunluk -lt 8 -or $uzunluk -gt 20) {
        Write-Output "`nGeçersiz uzunluk. Varsayılan olarak 12 karakterlik bir şifre oluşturulacak.`n"
        $uzunluk = 12
    }

    # Güçlü şifre oluştur
    $sifre = GuvenliSifreOlustur -uzunluk $uzunluk

    # Yeni kullanıcıyı kaydet
    KullaniciKaydet -hesap $hesap -email $email -sifre $sifre -dosyaYolu $dosyaYolu -sifrelemeAnahtari $sifrelemeAnahtari

    Write-Output "`nKullanıcı güçlü bir şifre ile başarıyla kaydedildi: $sifre`n"
}

# JSON dosyasına yeni kullanıcı kaydet
function KullaniciKaydet {
    param (
        [string]$hesap,
        [string]$email,
        [string]$sifre,
        [string]$dosyaYolu,
        [string]$sifrelemeAnahtari
    )

    $kullaniciVerileri = VerileriOku -dosyaYolu $dosyaYolu -sifrelemeAnahtari $sifrelemeAnahtari
    if ($kullaniciVerileri -isnot [System.Collections.ArrayList]) {
        $kullaniciVerileri = @($kullaniciVerileri)
    }

    # Yeni ID oluştur (mevcut en büyük ID'nin bir fazlası)
    $maxID = if ($kullaniciVerileri.Count -gt 0) { ($kullaniciVerileri | Measure-Object -Property ID -Maximum).Maximum } else { 0 }
    $yeniID = $maxID + 1

    $yeniKullanici = [PSCustomObject]@{
        ID    = $yeniID
        Hesap = $hesap
        Email = $email
        Sifre = $sifre
    }

    $kullaniciVerileri += $yeniKullanici
    $jsonData = $kullaniciVerileri | ConvertTo-Json -Depth 3
    $encryptedData = Encrypt-Data -Data $jsonData -Key $sifrelemeAnahtari
    Set-Content -Path $dosyaYolu -Value $encryptedData -Encoding UTF8

    Write-Output "`nKullanıcı başarıyla kaydedildi. Kullanıcı ID: $yeniID`n"
}

# Kayıtlı kullanıcıları listele
function KullaniciListele {
    param (
        [string]$dosyaYolu,
        [string]$sifrelemeAnahtari
    )

    $kullaniciVerileri = VerileriOku -dosyaYolu $dosyaYolu -sifrelemeAnahtari $sifrelemeAnahtari
    if ($kullaniciVerileri.Count -eq 0) {
        Write-Output "`nKayıtlı kullanıcı yok.`n"
    } else {
        Write-Output "`nKayıtlı Kullanıcılar:"
        foreach ($kullanici in $kullaniciVerileri) {
            Write-Output "ID: $($kullanici.ID), Hesap: $($kullanici.Hesap), Email: $($kullanici.Email), Şifre: $($kullanici.Sifre)"
        }
        Write-Output ""
    }
}

# Kullanıcı kaydını ID ile sil
function KullaniciSil {
    param (
        [int]$id,
        [string]$dosyaYolu,
        [string]$sifrelemeAnahtari
    )

    $kullaniciVerileri = VerileriOku -dosyaYolu $dosyaYolu -sifrelemeAnahtari $sifrelemeAnahtari
    $yeniVeriler = $kullaniciVerileri | Where-Object { $_.ID -ne $id }

    if ($yeniVeriler.Count -eq $kullaniciVerileri.Count) {
        Write-Output "`nSilinecek kullanıcı bulunamadı.`n"
    } else {
        $jsonData = $yeniVeriler | ConvertTo-Json -Depth 3
        $encryptedData = Encrypt-Data -Data $jsonData -Key $sifrelemeAnahtari
        Set-Content -Path $dosyaYolu -Value $encryptedData -Encoding UTF8

        Write-Output "`nKullanıcı başarıyla silindi.`n"
    }
}

# Kayıtlı kullanıcıları arama
function KullaniciAra {
    param (
        [string]$aramaKriteri,
        [string]$dosyaYolu,
        [string]$sifrelemeAnahtari
    )

    $kullaniciVerileri = VerileriOku -dosyaYolu $dosyaYolu -sifrelemeAnahtari $sifrelemeAnahtari
    $sonuc = $kullaniciVerileri | Where-Object {
        $_.Email -like "*$aramaKriteri*" -or $_.Sifre -like "*$aramaKriteri*" -or $_.Hesap -like "*$aramaKriteri*" -or $_.ID -eq $aramaKriteri
    }

    if ($sonuc.Count -eq 0) {
        Write-Output "`nArama kriterine uygun kullanıcı bulunamadı.`n"
    } else {
        Write-Output "`nArama Sonuçları:"
        foreach ($kullanici in $sonuc) {
            Write-Output "ID: $($kullanici.ID), Hesap: $($kullanici.Hesap), Email: $($kullanici.Email), Şifre: $($kullanici.Sifre)"
        }
        Write-Output ""
    }
}
# Sunucu Ayarlarını Kaydetme ve Yükleme Fonksiyonları
function SunucuAyarlariniKaydet {
    param (
        [string]$ftpKullaniciAdi,
        [string]$ftpSifre,
        [string]$ftpAdres,
        [string]$ftpKonum,
        [string]$dosyaYolu,
        [string]$sifrelemeAnahtari
    )
    $ayarlar = [PSCustomObject]@{
        FtpKullaniciAdi = $ftpKullaniciAdi
        FtpSifre = $ftpSifre
        FtpAdres = $ftpAdres
        FtpKonum = $ftpKonum
    }
    $jsonData = $ayarlar | ConvertTo-Json -Depth 3
    $encryptedData = Encrypt-Data -Data $jsonData -Key $sifrelemeAnahtari
    Set-Content -Path $dosyaYolu -Value $encryptedData -Encoding UTF8
    Write-Output "`nSunucu ayarları başarıyla kaydedildi.`n"
}

function SunucuAyarlariniYukle {
    param (
        [string]$dosyaYolu,
        [string]$sifrelemeAnahtari
    )
    if (Test-Path -Path $dosyaYolu) {
        try {
            $encryptedData = Get-Content -Path $dosyaYolu -Raw
            $jsonData = Decrypt-Data -Data $encryptedData -Key $sifrelemeAnahtari
            return $jsonData | ConvertFrom-Json
        }
        catch {
            Write-Output "Girmiş olduğunuz anahtar kelime hatalı. Lütfen doğru anahtar kelimeyi giriniz."
            return $null
        }
    }
    else {
        return $null
    }
}

function FtpYedekYukle {
    param (
        [string]$ftpKullaniciAdi,
        [string]$ftpSifre,
        [string]$ftpAdres,
        [string]$ftpKonum,  # ftp konumunu klasör olarak alıyoruz
        [string]$dosyaYolu   # yüklemek istediğimiz dosyanın adını alıyoruz
    )

    $currentDirectory = Get-Location
    $fullDosyaYolu = [System.IO.Path]::GetFullPath((Join-Path -Path $currentDirectory -ChildPath $dosyaYolu))

    # FTP URI'sini oluştur
    $ftpUri = if ($ftpAdres.StartsWith("ftp://")) { 
        "$ftpAdres/$ftpKonum$(Split-Path -Leaf $dosyaYolu)"  # Dosya adını almak için Split-Path kullanıyoruz
    } else { 
        "ftp://$ftpAdres/$ftpKonum$(Split-Path -Leaf $dosyaYolu)" 
    }

    # $ftpKonum'un sonuna bir eğik çizgi ekleyerek doğru konum oluşturma
    $ftpKonum = "$ftpKonum/"
    $ftpUri = if ($ftpAdres.StartsWith("ftp://")) { 
        "$ftpAdres/$ftpKonum$(Split-Path -Leaf $dosyaYolu)"  
    } else { 
        "ftp://$ftpAdres/$ftpKonum$(Split-Path -Leaf $dosyaYolu)" 
    }

    Write-Output "`nKopyalamaya çalıştığı adres: $ftpUri`n"
    Write-Output "`nDosya okunuyor ve gönderilmeye hazırlanıyor: $fullDosyaYolu`n"

    try {
        # FTP isteğini oluştur
        $ftpRequest = [System.Net.FtpWebRequest]::Create($ftpUri)
        $ftpRequest.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
        $ftpRequest.Credentials = New-Object System.Net.NetworkCredential($ftpKullaniciAdi, $ftpSifre)
        $ftpRequest.UsePassive = $true
        $ftpRequest.UseBinary = $true
        $ftpRequest.KeepAlive = $false

        # Dosyayı okuma
        $fileContent = [System.IO.File]::ReadAllBytes($fullDosyaYolu)
        $ftpRequest.ContentLength = $fileContent.Length

        # Hata ayıklama
        Write-Output "Yükleniyor... Lütfen bekleyin."

        # Akışa yazma
        $requestStream = $ftpRequest.GetRequestStream()
        $requestStream.Write($fileContent, 0, $fileContent.Length)
        $requestStream.Close()

        # Yanıt alma
        $ftpResponse = $ftpRequest.GetResponse()
        Write-Output "`nYükleme başarılı: $fullDosyaYolu dosyası $ftpUri adresine yüklendi (Kullanıcı: $ftpKullaniciAdi)`n"
        $ftpResponse.Close()
    }
    catch {
        Write-Output "`nYükleme sırasında bir hata oluştu: $_`n"
        Write-Output "`nKopyalamaya çalıştığı adres: $ftpUri`n"
        Write-Output "`nFTP Kullanıcı Adı: $ftpKullaniciAdi`n"
        Write-Output "`nFTP Şifre: $ftpSifre`n"
        Write-Output "Lütfen FTP konumunun ve dosya yolunun doğru olduğundan emin olun." 
    }
}



function AnaMenu {
    Clear-Host  # Ekranı temizler
    Write-Output "`nSeçim Yapın:"
    Write-Output "1 - Yeni Kullanıcı Kaydet"
    Write-Output "2 - Kayıtlı Kullanıcıları Listele"
    Write-Output "3 - Kullanıcı Ara"
    Write-Output "4 - Güvenli Şifre ile Kullanıcı Kaydet"
    Write-Output "5 - Kullanıcı Sil (ID ile)"
    Write-Output "6 - Veritabanı Yedeğini FTP'ye Yükle"
    Write-Output "7 - Veritabanını FTP'den Çek"
	Write-Output "8 - Sunucu Ayarları"
    Write-Output "0 - Çıkış"
    Write-Output ""
    $secim = Read-Host "Seçiminiz"
    switch ($secim) {
       
	   
	   "1" {
            $hesap = Read-Host "Hesap Adını Girin"
            $email = Read-Host "Email Girin"
            $sifre = Read-Host "Şifre Girin"
            if ($hesap -and $email -and $sifre) {
                KullaniciKaydet -hesap $hesap -email $email -sifre $sifre -dosyaYolu $dosyaYolu -sifrelemeAnahtari $sifrelemeAnahtari
                Write-Output "`nKullanıcı başarıyla kaydedildi.`n"
            } else {
                Write-Output "`nGeçersiz girdi. Lütfen tekrar deneyin.`n"
            }
            Read-Host "Ana menüye dönmek için bir tuşa basın..."
        }
        "2" {
            KullaniciListele -dosyaYolu $dosyaYolu -sifrelemeAnahtari $sifrelemeAnahtari
            Read-Host "`nListeleme tamamlandı. Ana menüye dönmek için bir tuşa basın..."
        }
        "3" {
            $aramaKriteri = Read-Host "Arama yapmak istediğiniz Hesap, Email veya Şifre girin"
            KullaniciAra -aramaKriteri $aramaKriteri -dosyaYolu $dosyaYolu -sifrelemeAnahtari $sifrelemeAnahtari
            Read-Host "`nArama tamamlandı. Ana menüye dönmek için bir tuşa basın..."
        }
        "4" {
            $hesap = Read-Host "Hesap Adını Girin"
            $email = Read-Host "Email Girin"
            if ($email) {
                GuvenliKullaniciKaydet -hesap $hesap -email $email -dosyaYolu $dosyaYolu -sifrelemeAnahtari $sifrelemeAnahtari
                Write-Output "`nKullanıcı başarıyla güvenli şifre ile kaydedildi.`n"
            } else {
                Write-Output "`nGeçersiz e-posta. Lütfen tekrar deneyin.`n"
            }
            Read-Host "Ana menüye dönmek için bir tuşa basın..."
        }
        "5" {
            $id = Read-Host "Silmek istediğiniz Kullanıcı ID'sini girin"
            if ([int]::TryParse($id, [ref]$null)) {
                $id = [int]$id  # Burada dönüşüm yapıyoruz
                KullaniciSil -id $id -dosyaYolu $dosyaYolu -sifrelemeAnahtari $sifrelemeAnahtari
                Write-Output "`nKullanıcı başarıyla silindi.`n"
            } else {
                Write-Output "`nGeçersiz ID. Lütfen tekrar deneyin.`n"
            }
            Read-Host "Ana menüye dönmek için bir tuşa basın..."
        }
        "6" {
            $ftpAyarlar = SunucuAyarlariniYukle -dosyaYolu ".\settings.json" -sifrelemeAnahtari $sifrelemeAnahtari
            if ($null -eq $ftpAyarlar) {
                Write-Output "`nLütfen Önce Sunucu Ayarlarını Yapın.`n"
            } else {
                $ftpKullaniciAdi = $ftpAyarlar.FtpKullaniciAdi
                $ftpSifre = $ftpAyarlar.FtpSifre
                $ftpAdres = $ftpAyarlar.FtpAdres
                $ftpKonum = $ftpAyarlar.FtpKonum
                Write-Output "`nFTP İşlem Detayları: Kullanıcı - $ftpKullaniciAdi, Şifre - $ftpSifre, Adres - $ftpAdres, Konum - $ftpKonum`n"
                FtpYedekYukle -ftpKullaniciAdi $ftpKullaniciAdi -ftpSifre $ftpSifre -ftpAdres $ftpAdres -ftpKonum $ftpKonum -dosyaYolu "bt.json"
            }
            Read-Host "Ana menüye dönmek için bir tuşa basın..."
        }
        "8" {
            $ftpAyarlar = SunucuAyarlariniYukle -dosyaYolu ".\settings.json" -sifrelemeAnahtari $sifrelemeAnahtari
            
            if ($null -eq $ftpAyarlar) {
                $ftpKullaniciAdi = Read-Host "FTP Kullanıcı Adını Girin"
                $ftpSifre = Read-Host "FTP Şifresini Girin"
                $ftpAdres = Read-Host "FTP Adresini Girin"
                $ftpKonum = Read-Host "FTP Konumunu Girin"
                SunucuAyarlariniKaydet -ftpKullaniciAdi $ftpKullaniciAdi -ftpSifre $ftpSifre -ftpAdres $ftpAdres -ftpKonum $ftpKonum -dosyaYolu ".\settings.json" -sifrelemeAnahtari $sifrelemeAnahtari
                Write-Output "Yeni ayarlar kaydedildi."
            } else {
                Write-Output "Mevcut FTP Ayarları:"
                Write-Output "FTP ADRES: $($ftpAyarlar.FtpAdres)"
                Write-Output "FTP KULLANICI ADI: $($ftpAyarlar.FtpKullaniciAdi)"
                $devamEt = Read-Host "Yeni ayar girmek ister misiniz? (E/H)"
                if ($devamEt -eq "E") {
                    $ftpKullaniciAdi = Read-Host "Yeni FTP Kullanıcı Adını Girin"
                    $ftpSifre = Read-Host "Yeni FTP Şifresini Girin"
                    $ftpAdres = Read-Host "Yeni FTP Adresini Girin"
                    $ftpKonum = Read-Host "Yeni FTP Konumunu Girin"
                    SunucuAyarlariniKaydet -ftpKullaniciAdi $ftpKullaniciAdi -ftpSifre $ftpSifre -ftpAdres $ftpAdres -ftpKonum $ftpKonum -dosyaYolu ".\settings.json" -sifrelemeAnahtari $sifrelemeAnahtari
                    Write-Output "Yeni ayarlar kaydedildi."
                }
            }
            Read-Host "Ana menüye dönmek için bir tuşa basın..."
        }
	   
	   
        "7" {
            $ftpAyarlar = SunucuAyarlariniYukle -dosyaYolu ".\settings.json" -sifrelemeAnahtari $sifrelemeAnahtari
            if ($null -eq $ftpAyarlar) {
                Write-Output "`nLütfen Önce Sunucu Ayarlarını Yapın.`n"
            } else {
                $ftpKullaniciAdi = $ftpAyarlar.FtpKullaniciAdi
                $ftpSifre = $ftpAyarlar.FtpSifre
                $ftpAdres = $ftpAyarlar.FtpAdres
                $ftpKonum = $ftpAyarlar.FtpKonum
                FtpYedekIndir -ftpKullaniciAdi $ftpKullaniciAdi -ftpSifre $ftpSifre -ftpAdres $ftpAdres -ftpKonum $ftpKonum -dosyaAdi "bt.json" -hedefDosyaAdi "bt_yedek.json"
            }
            Read-Host "Ana menüye dönmek için bir tuşa basın..."
        }

        "0" {
            exit
        }
        default {
            Write-Output "`nGeçersiz seçim. Lütfen tekrar deneyin.`n"
            Read-Host "Ana menüye dönmek için bir tuşa basın..."
        }
    }
    AnaMenu
}
function FtpYedekIndir {
    param (
        [string]$ftpKullaniciAdi,
        [string]$ftpSifre,
        [string]$ftpAdres,
        [string]$ftpKonum,
        [string]$dosyaAdi,
        [string]$hedefDosyaAdi
    )
    # FTP bağlantı bilgilerini ayarla
    $ftpUri = "$ftpAdres/$ftpKonum/$dosyaAdi"
    $currentDirectory = (Get-Location).Path
    $hedefDosyaYolu = Join-Path -Path $currentDirectory -ChildPath $hedefDosyaAdi
    
    try {
        Write-Output "`nDosya indiriliyor: $ftpUri"
        $webClient = New-Object System.Net.WebClient
        $webClient.Credentials = New-Object System.Net.NetworkCredential($ftpKullaniciAdi, $ftpSifre)
        
        # Dosya indirme işlemi
        $webClient.DownloadFile($ftpUri, $hedefDosyaYolu)
        Write-Output "`nVeritabanı dosyası başarıyla '$hedefDosyaYolu' olarak indirildi.`n"
    } catch {
        # Hata durumunda daha fazla bilgi yazdır
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode
            $statusDescription = $_.Exception.Response.StatusDescription
            
            if ($statusCode -eq 550) {
                Write-Output "`nYedek dosyası FTP'de bulunmuyor.`n"
            } else {
                Write-Output "`nHata: $statusCode - $statusDescription`n"
            }
        } else {
            Write-Output "`nHata: $($_.Exception.Message)`n"
        }
        Write-Output "`nFTP sunu üzerinde daha önce alınmış herhangi bir yedek bulunmuyor.`n"
    }
}


# Ana menüyü başlat
AnaMenu
