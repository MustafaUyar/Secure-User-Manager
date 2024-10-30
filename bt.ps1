# JSON dosya yolu
$dosyaYolu = ".\bt.json"
$ftpBilgileriDosyaYolu = ".\settings.json"
$ftpYuklenenDosya = "bt.json"
$ftpGelenDosya = "bt_yedek.json"

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

    Write-Host "`nKullanıcı başarıyla kaydedildi." -ForegroundColor Green
    Write-Host "Kullanıcı ID: $yeniID`n" -ForegroundColor Cyan
}

# Kayıtlı kullanıcıları listele
function KullaniciListele {
    param (
        [string]$dosyaYolu,
        [string]$sifrelemeAnahtari
    )

    $kullaniciVerileri = VerileriOku -dosyaYolu $dosyaYolu -sifrelemeAnahtari $sifrelemeAnahtari
    if ($kullaniciVerileri.Count -eq 0) {
        Write-Host "`nKayıtlı kullanıcı yok.`n" -ForegroundColor Red
    } else {
        Write-Host "`nKayıtlı Kullanıcılar:" -ForegroundColor Yellow
        foreach ($kullanici in $kullaniciVerileri) {
            Write-Host "ID: $($kullanici.ID), " -NoNewline
            Write-Host "Hesap: $($kullanici.Hesap)" -ForegroundColor Cyan -NoNewline
            Write-Host ", Email: $($kullanici.Email)" -ForegroundColor Magenta -NoNewline
            Write-Host ", Şifre: $($kullanici.Sifre)" -ForegroundColor Green
        }
        Write-Host ""
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
        Write-Host "`nSilinecek kullanıcı bulunamadı.`n" -ForegroundColor Red
    } else {
        $jsonData = $yeniVeriler | ConvertTo-Json -Depth 3
        $encryptedData = Encrypt-Data -Data $jsonData -Key $sifrelemeAnahtari
        Set-Content -Path $dosyaYolu -Value $encryptedData -Encoding UTF8

        Write-Host "`nKullanıcı başarıyla silindi.`n" -ForegroundColor Green
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
        Write-Host "`nArama kriterine uygun kullanıcı bulunamadı.`n" -ForegroundColor Red
    } else {
        Write-Host "`nArama Sonuçları:" -ForegroundColor Green
        foreach ($kullanici in $sonuc) {
            Write-Host "ID: $($kullanici.ID), Hesap: $($kullanici.Hesap), Email: $($kullanici.Email), Şifre: $($kullanici.Sifre)" -ForegroundColor White
        }
        Write-Host ""
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
    
    Write-Host "`nSunucu ayarları başarıyla kaydedildi." -ForegroundColor Green
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
        [string]$ftpKonum,  # FTP konumunu klasör olarak alıyoruz
        [string]$dosyaYolu   # Yüklemek istediğimiz dosyanın adını alıyoruz
    )

    $currentDirectory = Get-Location
    $fullDosyaYolu = [System.IO.Path]::GetFullPath((Join-Path -Path $currentDirectory -ChildPath $dosyaYolu))

    # FTP URI'sini oluştur (ftpKonum'un sonuna / ekleniyor)
    $ftpUri = if ($ftpAdres.StartsWith("ftp://")) { 
        "$ftpAdres/$ftpKonum/$($dosyaYolu)"  # $dosyaYolu doğrudan kullanılıyor
    } else { 
        "ftp://$ftpAdres/$ftpKonum/$($dosyaYolu)" 
    }

    Write-Host "`nKopyalamaya çalıştığı adres: $ftpUri`n" -ForegroundColor Cyan
    Write-Host "Dosya okunuyor ve gönderilmeye hazırlanıyor: $fullDosyaYolu`n" -ForegroundColor Yellow

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
        Write-Host "Yükleniyor... Lütfen bekleyin." -ForegroundColor Yellow

        # Akışa yazma
        $requestStream = $ftpRequest.GetRequestStream()
        $requestStream.Write($fileContent, 0, $fileContent.Length)
        $requestStream.Close()

        # Yanıt alma
        $ftpResponse = $ftpRequest.GetResponse()
        Write-Host "`nYükleme başarılı: $fullDosyaYolu dosyası $ftpUri adresine yüklendi.`n" -ForegroundColor Green
        $ftpResponse.Close()
    }
    catch {
        Write-Host "`nYükleme sırasında bir hata oluştu: $_`n" -ForegroundColor Red
        Write-Host "Lütfen FTP konumunun ve dosya yolunun doğru olduğundan emin olun." -ForegroundColor Yellow
    }
}


function HesapGuncelle {
    param (
        [int]$kullaniciID,
        [string]$yeniHesap,
        [string]$yeniEmail,
        [string]$yeniSifre,
        [string]$sifrelemeAnahtari
    )

    # Dosya yolunu kontrol et
    if (-not [string]::IsNullOrWhiteSpace($dosyaYolu)) {
        # Dosyanın var olup olmadığını kontrol et
        if (Test-Path -Path $dosyaYolu) {
            # Verileri oku
            $kullaniciVerileri = VerileriOku -dosyaYolu $dosyaYolu -sifrelemeAnahtari $sifrelemeAnahtari

            # Belirtilen ID ile kullanıcıyı bul
            $kullanici = $kullaniciVerileri | Where-Object { $_.ID -eq $kullaniciID }
            if ($null -eq $kullanici) {
                Write-Output "Hata: Kullanıcı bulunamadı. ID: $kullaniciID"
                 Write-Output "Hata: Dosya yolu geçersiz veya boş. Dosya Yolu: $dosyaYolu"
                return
            }

            # Kullanıcı verilerini güncelle
            $kullanici.Hesap = $yeniHesap
            $kullanici.Email = $yeniEmail
            $kullanici.Sifre = $yeniSifre

            # Verileri geri yaz
            $jsonData = $kullaniciVerileri | ConvertTo-Json -Depth 3
            $encryptedData = Encrypt-Data -Data $jsonData -Key $sifrelemeAnahtari
            Set-Content -Path $dosyaYolu -Value $encryptedData -Encoding UTF8

            Write-Output "Kullanıcı başarıyla güncellendi. ID: $kullaniciID"
        } else {
            Write-Output "Hata: Dosya bulunamadı: $dosyaYolu"
        }
    } else {
        Write-Output "Hata: Dosya yolu geçersiz veya boş. Dosya Yolu: $dosyaYolu"
    }
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

    # FTP URI'sini oluştur
    $ftpUri = if ($ftpAdres.StartsWith("ftp://")) { 
        "$ftpAdres/$ftpKonum/$dosyaAdi" 
    } else { 
        "ftp://$ftpAdres/$ftpKonum/$dosyaAdi" 
    }

    # İndirme hedef dosya yolunu ayarla
    $currentDirectory = (Get-Location).Path
    $hedefDosyaYolu = Join-Path -Path $currentDirectory -ChildPath $hedefDosyaAdi

    try {
        Write-Output "`nDosya indiriliyor: $ftpUri"
        
        # WebClient oluştur ve kimlik bilgilerini ayarla
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
        Write-Output "`nFTP sunucusunda daha önce alınmış herhangi bir yedek bulunmuyor.`n"
    }
}




function GirisKontrol {
    if (-not (Test-Path -Path $dosyaYolu)) {
        Write-Output "Veri dosyası bulunamadı, girişe izin verildi."

        if (Test-Path -Path $ftpBilgileriDosyaYolu) {
            Remove-Item -Path $ftpBilgileriDosyaYolu -Force
            Write-Output "FTP Ayar dosyası bulundu ve silindi."
        }

        AnaMenu
        return
    }

    $veriler = VerileriOku -dosyaYolu $dosyaYolu -sifrelemeAnahtari $sifrelemeAnahtari

    if ($veriler.Count -eq 0) {
        Write-Output "Hatalı anahtar kelime. Ana menüye erişim engellendi."
        exit  
    } else {
        Write-Output "Giriş başarılı."
        AnaMenu  
    }
}


function AnaMenu {
   Clear-Host

# Menü başlığı ve ayırıcı çizgi
Write-Host "====================" -ForegroundColor DarkCyan
Write-Host "     ANA MENÜ       " -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor DarkCyan
Write-Host ""

# Menü seçenekleri
Write-Host "1 - Yeni Kullanıcı Kaydet" -ForegroundColor Green
Write-Host "2 - Kayıtlı Kullanıcıları Listele" -ForegroundColor Green
Write-Host "3 - Hesap Bilgilerini Güncelle (ID ile)" -ForegroundColor Green
Write-Host "4 - Kullanıcı Ara" -ForegroundColor Green
Write-Host "5 - Güvenli Şifre ile Kullanıcı Kaydet" -ForegroundColor Green
Write-Host "6 - Kullanıcı Sil (ID ile)" -ForegroundColor Green
Write-Host "7 - Veritabanı Yedeğini FTP'ye Yükle" -ForegroundColor Green
Write-Host "8 - Veritabanını FTP'den Çek" -ForegroundColor Green
Write-Host "9 - Sunucu Ayarları" -ForegroundColor Green
Write-Host "0 - Çıkış" -ForegroundColor Red

# Alt çizgi ve seçim yönlendirmesi
Write-Host ""
Write-Host "====================" -ForegroundColor DarkCyan
Write-Host "Bir seçim yapın:" -ForegroundColor Yellow
Write-Host "====================" -ForegroundColor DarkCyan
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
    $id = Read-Host "Güncellenecek hesabın ID'sini girin"
    if ([int]::TryParse($id, [ref]$null)) {
        $id = [int]$id  # ID’yi tam sayıya çeviriyoruz

        # Kullanıcı verilerini oku
        $kullaniciVerileri = VerileriOku -dosyaYolu $dosyaYolu -sifrelemeAnahtari $sifrelemeAnahtari

        # Belirtilen ID ile kullanıcıyı bul
        $kullanici = $kullaniciVerileri | Where-Object { $_.ID -eq $id }
        if ($null -eq $kullanici) {
            Write-Host "Kullanıcı bulunamadı: ID = $id" -ForegroundColor Red
            return
        }

        # Mevcut bilgileri göster
    Write-Host "`nMevcut Kullanıcı Bilgileri:`n" -ForegroundColor Cyan
    Write-Host "Hesap: $($kullanici.Hesap)" -ForegroundColor Yellow
    Write-Host "Email: $($kullanici.Email)" -ForegroundColor Yellow
    Write-Host "Şifre: (Gizli)" -ForegroundColor Red  # Şifreyi gizli tutalım


        # Kullanıcıdan yeni bilgileri al
# Kullanıcıdan yeni bilgiler alırken renklendirme
Write-Host "`nBilgi Güncelleme:" -ForegroundColor Cyan
$yeniHesap = Read-Host -Prompt "Yeni Hesap Adı girin (boş bırakmak mevcut değeri korur)"
$yeniEmail = Read-Host -Prompt "Yeni E-posta adresi girin (boş bırakmak mevcut değeri korur)"
$yeniSifre = Read-Host -Prompt "Yeni Şifre girin (boş bırakmak mevcut değeri korur)"


        # Mevcut değerleri korumak için boş değerleri kontrol et
        if (-not [string]::IsNullOrWhiteSpace($yeniHesap)) {
            $kullanici.Hesap = $yeniHesap
        }
        if (-not [string]::IsNullOrWhiteSpace($yeniEmail)) {
            $kullanici.Email = $yeniEmail
        }
        if (-not [string]::IsNullOrWhiteSpace($yeniSifre)) {
            $kullanici.Sifre = $yeniSifre
        }

        # Verileri geri yaz
        $jsonData = $kullaniciVerileri | ConvertTo-Json -Depth 3
        $encryptedData = Encrypt-Data -Data $jsonData -Key $sifrelemeAnahtari
        Set-Content -Path $dosyaYolu -Value $encryptedData -Encoding UTF8

        Write-Host "`nKullanıcı başarıyla güncellendi. ID: $($kullanici.ID)`n" -ForegroundColor Green
    } else {
        Write-Host "Geçersiz ID girdiniz. Lütfen bir sayı girin." -ForegroundColor Red
    }
    Write-Host "`nAna menüye dönmek için bir tuşa basın..." -ForegroundColor Cyan
    Read-Host | Out-Null

}

        "4" {
            $aramaKriteri = Read-Host "Arama yapmak istediğiniz Hesap, Email veya Şifre girin"
            KullaniciAra -aramaKriteri $aramaKriteri -dosyaYolu $dosyaYolu -sifrelemeAnahtari $sifrelemeAnahtari
            Read-Host "`nArama tamamlandı. Ana menüye dönmek için bir tuşa basın..."
        }
        "5" {
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
        "6" {
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
        "7" {
            $ftpAyarlar = SunucuAyarlariniYukle -dosyaYolu $ftpBilgileriDosyaYolu -sifrelemeAnahtari $sifrelemeAnahtari
            if ($null -eq $ftpAyarlar) {
                Write-Host "`nLütfen Önce Sunucu Ayarlarını Yapın.`n" -ForegroundColor Red
            } else {
                Write-Host "`nFTP İşlem Detayları:" -ForegroundColor Cyan
                Write-Host "  Kullanıcı: $ftpKullaniciAdi" -ForegroundColor Yellow
                Write-Host "  Şifre: $ftpSifre" -ForegroundColor Yellow
                Write-Host "  Adres: $ftpAdres" -ForegroundColor Yellow
                Write-Host "  Konum: $ftpKonum" -ForegroundColor Yellow
                Write-Output "`nFTP İşlem Detayları: Kullanıcı - $ftpKullaniciAdi, Şifre - $ftpSifre, Adres - $ftpAdres, Konum - $ftpKonum`n"
                FtpYedekYukle -ftpKullaniciAdi $ftpKullaniciAdi -ftpSifre $ftpSifre -ftpAdres $ftpAdres -ftpKonum $ftpKonum -dosyaYolu $ftpYuklenenDosya
            }
            Read-Host "Ana menüye dönmek için bir tuşa basın..."
        }

	   
	   
"8" {
    $ftpAyarlar = SunucuAyarlariniYukle -dosyaYolu $ftpBilgileriDosyaYolu -sifrelemeAnahtari $sifrelemeAnahtari
    if ($null -eq $ftpAyarlar) {
        Write-Host "`nLütfen Önce Sunucu Ayarlarını Yapın.`n" -ForegroundColor Red
    } else {
        $ftpKullaniciAdi = $ftpAyarlar.FtpKullaniciAdi
        $ftpSifre = $ftpAyarlar.FtpSifre
        $ftpAdres = $ftpAyarlar.FtpAdres
        $ftpKonum = $ftpAyarlar.FtpKonum
        
        Write-Host "`nFTP İşlem Detayları:" -ForegroundColor Cyan
        Write-Host "  Kullanıcı: $ftpKullaniciAdi" -ForegroundColor Yellow
        Write-Host "  Şifre: $ftpSifre" -ForegroundColor Yellow
        Write-Host "  Adres: $ftpAdres" -ForegroundColor Yellow
        Write-Host "  Konum: $ftpKonum" -ForegroundColor Yellow

        FtpYedekIndir -ftpKullaniciAdi $ftpKullaniciAdi -ftpSifre $ftpSifre -ftpAdres $ftpAdres -ftpKonum $ftpKonum -dosyaAdi $ftpYuklenenDosya -hedefDosyaAdi $ftpGelenDosya
    }
    Write-Host "`nAna menüye dönmek için bir tuşa basın..." -ForegroundColor Cyan
    Read-Host | Out-Null
}


"9" {
    $ftpAyarlar = SunucuAyarlariniYukle -dosyaYolu $ftpBilgileriDosyaYolu -sifrelemeAnahtari $sifrelemeAnahtari
    
    if ($null -eq $ftpAyarlar) {
        Write-Host "`nYeni FTP Ayarlarını Girmek İçin Bilgileri Girin:" -ForegroundColor Cyan
        $ftpKullaniciAdi = Read-Host "FTP Kullanıcı Adını Girin"
        $ftpSifre = Read-Host "FTP Şifresini Girin"
        $ftpAdres = Read-Host "FTP Adresini Girin"
        $ftpKonum = Read-Host "FTP Konumunu Girin"
        SunucuAyarlariniKaydet -ftpKullaniciAdi $ftpKullaniciAdi -ftpSifre $ftpSifre -ftpAdres $ftpAdres -ftpKonum $ftpKonum -dosyaYolu $ftpBilgileriDosyaYolu -sifrelemeAnahtari $sifrelemeAnahtari
        Write-Host "Yeni ayarlar kaydedildi." -ForegroundColor Green
    } else {
        Write-Host "`nMevcut FTP Ayarları:" -ForegroundColor Cyan
        Write-Host "  FTP ADRES: $($ftpAyarlar.FtpAdres)" -ForegroundColor Yellow
        Write-Host "  FTP KULLANICI ADI: $($ftpAyarlar.FtpKullaniciAdi)" -ForegroundColor Yellow
        $devamEt = Read-Host "Yeni ayar girmek ister misiniz? (E/H)"
        if ($devamEt -eq "E") {
            Write-Host "`nYeni FTP Ayarlarını Girmek İçin Bilgileri Girin:" -ForegroundColor Cyan
            $ftpKullaniciAdi = Read-Host "Yeni FTP Kullanıcı Adını Girin"
            $ftpSifre = Read-Host "Yeni FTP Şifresini Girin"
            $ftpAdres = Read-Host "Yeni FTP Adresini Girin"
            $ftpKonum = Read-Host "Yeni FTP Konumunu Girin"
            SunucuAyarlariniKaydet -ftpKullaniciAdi $ftpKullaniciAdi -ftpSifre $ftpSifre -ftpAdres $ftpAdres -ftpKonum $ftpKonum -dosyaYolu $ftpBilgileriDosyaYolu -sifrelemeAnahtari $sifrelemeAnahtari
            Write-Host "Yeni ayarlar kaydedildi." -ForegroundColor Green
        }
    }
    Write-Host "`nAna menüye dönmek için bir tuşa basın..." -ForegroundColor Cyan
    Read-Host | Out-Null
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



GirisKontrol  # Giriş kontrolü ile başlatılı
