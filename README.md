
# **SecureUserManager**

### Güvenli Kullanıcı Yönetimi ve Şifreleme Scripti

**Proje Açıklaması**  
SecureUserManager, kullanıcı bilgilerini güvenli bir şekilde saklamak ve yönetmek için geliştirilmiş bir PowerShell scriptidir. Bu proje, bilgileri JSON dosyasına şifrelenmiş formatta kaydeder, güçlü bir şifreleme algoritması kullanarak veri güvenliğini sağlar ve kullanıcıları ekleme, şifreleme ve yedekleme işlevleri sunar.

---

## **Özellikler**
- **Kullanıcı Ekleme ve Şifreleme**: Kullanıcı bilgilerini JSON formatında saklayarak şifreleme işlemi gerçekleştirir.
- **Güçlü Şifreleme Anahtarı**: Kullanıcıdan alınan şifreleme anahtarını 256-bit uzunluğa genişletir ve güçlü bir güvenlik sağlar.
- **Veri Yedekleme**: Veritabanını FTP sunucusuna yedekleme imkanı sunar.
- **Kullanıcı Arayüzü**: Komut satırı tabanlı kullanıcı dostu bir menü içerir.

---

## **Kurulum**

1. Projeyi bilgisayarınıza klonlayın:
   ```bash
   git clone https://github.com/MustafaUyar/Secure-User-Manager.git
   cd SecureUserManager
   ```

2. PowerShell'de `ExecutionPolicy` ayarlarını geçici olarak değiştirin:
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope Process
   ```

3. Scripti çalıştırarak kullanıcı kayıtlarını ve yedekleme işlemlerini yönetebilirsiniz:
   ```powershell
   .\bt.ps1
   ```

---

## **Kullanım**

1. **Şifreleme Anahtarı Oluşturma**: Script çalıştırıldığında, kullanıcıdan bir şifreleme anahtarı istenir. Bu anahtar, JSON dosyasındaki kullanıcı bilgilerini şifrelemek için kullanılacaktır.

2. **Ana Menü**: Script çalıştırıldığında aşağıdaki seçenekleri sunan bir ana menü görüntülenir:
   - Kullanıcı Ekleme ve Şifreleme
   - Veritabanını Yedekleme
   - FTP Sunucusu Ayarlarını Yapılandırma
   - Kullanıcıları Yönetme ve Silme

3. **Veri Yedekleme**: Menüde 'Yedekleme' seçeneği, kullanıcıların FTP ayarlarını yapılandırmalarını ve verilerini otomatik olarak yedeklemelerini sağlar.

---

## **Katkıda Bulunma**

1. Bu projeyi klonlayın ve geliştirmek istediğiniz yeni bir dal oluşturun.
   ```bash
   git checkout -b yeni-ozellik
   ```

2. Değişikliklerinizi ekleyin ve bu dalda saklayın:
   ```bash
   git add .
   git commit -m "Yeni özellik eklendi"
   ```

3. GitHub’a gönderin ve bir "Pull Request" oluşturun.

---

## **Lisans**
Bu proje MIT Lisansı ile lisanslanmıştır. Detaylı bilgi için `LICENSE` dosyasını inceleyebilirsiniz.
