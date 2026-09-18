# DGX Spark Open WebUI

在 NVIDIA DGX Spark 上用 Docker Compose 部署 [Open WebUI](https://github.com/open-webui/open-webui)，並連接主機上的 [Ollama](https://ollama.com)。一行指令即可更新映像並啟動服務。

## 架構

```text
瀏覽器 ─▶ Spark:3000 ─▶ open-webui 容器 (:8080) ─▶ host.docker.internal:11434 ─▶ Ollama（跑在主機上）
```

- Open WebUI 跑在容器內，資料（帳號、對話紀錄、設定）存在 Docker volume `open-webui`，重建容器不會遺失。
- Ollama 直接跑在主機上，容器透過 `host.docker.internal` 連過去。

## 前置需求

- Docker 與 Docker Compose v2 plugin（指令是 `docker compose`，不是舊版的 `docker-compose`），且目前使用者有權限操作 Docker。
- 主機已安裝 Ollama，並已下載模型（例如 `ollama pull <model>`）。
- Ollama 必須監聽 `0.0.0.0`，見下一節。

### 設定 Ollama 監聽位址

Ollama 預設只監聽 `127.0.0.1`，容器連不到。若 Ollama 以 systemd 服務安裝：

```bash
sudo systemctl edit ollama.service
```

在編輯器中加入：

```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
```

然後重啟：

```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

> 監聽 `0.0.0.0` 後，區網內其他裝置也連得到 Ollama（沒有驗證機制）。需要的話請用防火牆限制 11434 port。

## 快速開始

```bash
git clone https://github.com/Prisvalis/Spark_Open-WebUI.git
cd Spark_Open-WebUI
chmod +x start_webui.sh
./start_webui.sh
```

腳本完成後會印出網址，預設為 `http://<Spark 的 IP>:3000`。第一個註冊的帳號會自動成為管理員。

## start_webui.sh

依序執行：檢查環境 → 拉取最新映像 → 啟動並等待服務 healthy（最多 5 分鐘）→ 顯示狀態與網址。啟動失敗時會印出最後 50 行 log 並以非 0 結束。

| 選項 | 說明 |
| --- | --- |
| `--no-pull` | 不拉取映像，使用本機現有的映像 |
| `--prune` | 完成後清除主機上所有 dangling image（更新後可回收舊映像的空間） |
| `-h`, `--help` | 顯示用法 |

拉取映像失敗時，正在執行的舊服務不會受影響。映像或設定有變動時 compose 才會重建容器，資料 volume 不受影響。

## 設定

可用環境變數，或在 `docker-compose.yaml` 同一層建立 `.env` 檔覆寫：

| 變數 | 預設值 | 說明 |
| --- | --- | --- |
| `WEBUI_PORT` | `3000` | 對外的 port |
| `WEBUI_IMAGE_TAG` | `main` | 映像 tag，可固定成特定版本，版本清單見 [Releases](https://github.com/open-webui/open-webui/releases) |
| `OLLAMA_BASE_URL` | `http://host.docker.internal:11434` | Ollama 位址 |

```env
# .env 範例
WEBUI_PORT=8080
WEBUI_IMAGE_TAG=main
```

`OLLAMA_BASE_URL` 只在第一次啟動時讀取。之後要改請到 Open WebUI 的 Admin Settings > Connections。

## 常用指令

```bash
docker compose ps                     # 服務狀態
docker compose logs -f open-webui     # 即時 log
docker compose restart open-webui     # 重啟服務
docker compose stop                   # 停止服務（保留容器與資料）
docker compose down                   # 移除容器（資料仍保留在 volume）
```

> 不要對 `docker compose down` 加 `-v`，那會連同資料 volume 一起刪除。

更新到最新版：重新執行 `./start_webui.sh`。

## 疑難排解

**Open WebUI 看不到任何模型**

先確認容器連得到 Ollama：

```bash
docker compose exec open-webui curl -s http://host.docker.internal:11434/api/tags
```

沒有回應通常是 Ollama 還在監聽 `127.0.0.1`，請依上方「設定 Ollama 監聽位址」處理。

**第一次啟動很久**

第一次啟動需要初始化資料庫並載入內建模型，會比平常慢。腳本最多等 5 分鐘，可用 `docker compose logs -f open-webui` 查看進度。

**`permission denied` / 無法連到 Docker daemon**

把目前使用者加進 docker 群組，重新登入後生效：

```bash
sudo usermod -aG docker $USER
```

**`bad interpreter: /usr/bin/env: 'bash\r'`**

腳本被轉成 Windows 換行（CRLF）。轉回 LF：

```bash
sed -i 's/\r$//' start_webui.sh
```

**3000 port 已被占用**

用 `WEBUI_PORT` 換一個 port，見上方「設定」。

## 授權

[MIT License](LICENSE)
