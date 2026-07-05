# Coolify Production Playbook 🇹🇷

**Coolify kurmak 10 dakika. Onu bir yıl boyunca production'da işletmek asıl mesele.**

Bu repo, gerçek ve gelir üreten bir SaaS'ı (canlı pazaryeri siparişleri işleyen bir e-ticaret depo yönetim platformu) **aylık €13'luk Hetzner VPS** üzerinde [Coolify](https://coolify.io) ile işletirken öğrendiğimiz her şey — yaşanan kazalar, kalıcı çözümler ve aynı duvarlara toslamayasın diye kopyala-yapıştır dosyalar.

> 🇬🇧 English version: [README.md](README.md)

## 🤖 AI asistan mı kullanıyorsun? Buradan başla

Bu playbook, AI kod asistanları (Claude Code, Cursor, Codex, ...) tarafından uygulanmak üzere tasarlandı. Asistanına bu repoyu göster ve şunu de:

> *"Bu repoyu oku ve sunucumu buna göre sıkılaştır / CI/CD'mi buna göre kur."*

Her rehber makine-dostu bir yapıda: **Önkoşullar → Kontrol → Uygula → Doğrula**. Böylece asistan komutları körlemesine çalıştırmak yerine senin sunucuna göre uyarlar. Ajan talimatları: [AGENTS.md](AGENTS.md).

Bilerek CLI yazmadık. Zaten bir CLI'n var: asistanın. Okunabilir bash + açıklamalı YAML, kara kutu bir binary'den daha iyidir — hem insan hem LLM için.

## İçerik

| Yol | Nedir |
|-----|-------|
| [`server-setup/setup.sh`](server-setup/setup.sh) | İnteraktif, idempotent sıkılaştırma script'i: swap, Docker log rotation, 3 kademeli disk temizlik cron'ları |
| [`templates/deploy.yml`](templates/deploy.yml) | Production'da kanıtlanmış CI/CD: test → seçici monorepo deploy → SSH üzerinden Coolify API |
| [`docker/`](docker/) | Node monorepo için ayrık Dockerfile'lar (API + statik web) ve "neden iki app" gerekçesi |
| [`docs/`](docs/) | Derin dalışlar: yaşadığımız her problem, neden olduğu, kalıcı çözümü |
| [`docs/incidents/`](docs/incidents/) | Gerçek production kazaları (anonimleştirilmiş) — ne bozuldu, neye mal oldu, ne değiştirdik |

## Bu reponun çözdüğü problemler

1. **[Cloudflare, GitHub deploy webhook'larını engelliyor](docs/cloudflare-bot-fight.md)** — Bot Fight Mode GitHub IP'lerini sessizce bloklar. Çözüm: Actions'tan SSH ile Coolify API tetikleme.
2. **[Disk dolup site düşüyor](docs/disk-cleanup.md)** — Docker build cache + loglar 80GB'ı aylar içinde yer. Çözüm: 3 kademeli otomatik temizlik + log rotation.
3. **[Monorepo'da her push her şeyi deploy ediyor](docs/selective-monorepo-deploy.md)** — Çözüm: `github.event.before` ile tam push aralığında path-filtreli deploy (`HEAD~1` değil — çoğu örnek bunu yanlış yapar).
4. **[Bozuk migration prod'u boot-loop'a sokuyor](docs/migration-smoke-test.md)** — Çözüm: CI'da boş PostgreSQL'e tüm migration zincirini uygula.
5. **[API+web için tek Dockerfile tüm siteyi düşürüyor](docs/two-apps-two-dockerfiles.md)** — Çözüm: iki Coolify app'i, iki Dockerfile. Bunu tam kesinti yaşayarak öğrendik.
6. **[Küçük VPS'te PostgreSQL sorunları](docs/postgres-small-vps.md)** — bağlantı tükenmesi, idle session'lar. Çözüm: `max_connections`, `idle_session_timeout`, 2GB swap.

## Hızlı başlangıç

Kurulum adımları ve secret tablosu için İngilizce [README](README.md#quick-start)'ye bak — komutlar aynı.

## Kanıtlandığı stack

Hetzner CCX13 (2 vCPU / 8 GB / 80 GB, ~€13/ay) · Coolify + Traefik · Cloudflare (ücretsiz plan) · Node.js monorepo (Hono API + React/Vite) · PostgreSQL · GitHub Actions. Hetzner'e özgü hiçbir şey yok — herhangi bir VPS sağlayıcısı olur.

## Katkı

Bizde olmayan bir Coolify production tuzağı mı buldun? Issue veya PR aç — özellikle incident yazıları. Şart: tekrarlanabilir olmalı ve çözüm gerçek bir sunucuda test edilmiş olmalı.

## Lisans

[MIT](LICENSE)
