# DGX Spark Open WebUI

在 NVIDIA DGX Spark 上用 Docker Compose 部署 [Open WebUI](https://github.com/open-webui/open-webui)，並透過主機上的 [LiteLLM Proxy](https://github.com/BerriAI/litellm) 取得模型。一行指令即可更新映像並啟動服務。

## 架構

```text
瀏覽器 ─▶ Spark:8080 ─▶ open-webui 容器（host 網路）─▶ 127.0.0.1:4000 LiteLLM Proxy ─▶ 模型後端
```

- Open WebUI 跑在容器內，使用 host 網路（`network_mode: host`）：沒有 port mapping，服務直接監聽主機的 8080（可用 `PORT` 修改），並以 `127.0.0.1` 連到主機上的 LiteLLM。
- 模型統一由 LiteLLM Proxy 以 OpenAI 相容 API 提供，Ollama 直連已停用（`ENABLE_OLLAMA_API=false`）。
- 資料（帳號、對話紀錄、設定）存在 Docker volume `open-webui`，重建容器不會遺失。
- LiteLLM Proxy 不在本 repo 內，需自行在主機上運行。

## 專案結構

```text
.
├── docker/
│   └── docker-compose.yaml   # Open WebUI 服務定義
├── start_webui.sh            # 更新映像並啟動服務
├── .env.example              # .env 範本
├── .env                      # 自行建立，放 LITELLM_MASTER_KEY、PORT（勿 commit）
└── LICENSE
```

## 前置需求

- Docker 與 Docker Compose v2 plugin（指令是 `docker compose`，不是舊版的 `docker-compose`），且目前使用者有權限操作 Docker。
- LiteLLM Proxy 已在主機的 `127.0.0.1:4000` 運行。
- 主機的 8080 port（或你用 `PORT` 指定的 port）未被占用，host 網路會直接使用它。
- 專案根目錄有 `.env`（可複製 `.env.example` 後修改），至少要填入 LiteLLM Proxy 的 master key：

  ```env
  LITELLM_MASTER_KEY=你的金鑰
  ```

  `.env` 含有金鑰，請勿 commit。

## 快速開始

```bash
git clone https://github.com/Prisvalis/Spark_Open-WebUI.git
cd Spark_Open-WebUI
cp .env.example .env   # 然後在 .env 填入 LITELLM_MASTER_KEY
chmod +x start_webui.sh
./start_webui.sh
```

腳本完成後會印出網址，格式為 `http://<Spark 的 IP>:<PORT>`，預設 port 為 8080。全新安裝時，第一個註冊的帳號會自動成為管理員。

## start_webui.sh

依序執行：檢查環境 → 拉取最新映像 → 啟動並等待服務 healthy（最多 5 分鐘）→ 顯示狀態與網址。啟動失敗時會印出最後 50 行 log 並以非 0 結束。

| 選項 | 說明 |
| --- | --- |
| `--no-pull` | 不拉取映像，使用本機現有的映像 |
| `--prune` | 完成後清除主機上所有 dangling image（更新後可回收舊映像的空間） |
| `-h`, `--help` | 顯示用法 |

腳本固定使用 `docker/docker-compose.yaml`，並以專案根目錄作為 compose 的 project directory，所以可以從任何路徑執行，`.env` 也是讀根目錄那份。

拉取映像失敗時，正在執行的舊服務不會受影響。映像或設定有變動時 compose 才會重建容器，資料 volume 不受影響。

## 設定

在專案根目錄的 `.env` 設定：

| 變數 | 必填 | 預設 | 說明 |
| --- | --- | --- | --- |
| `LITELLM_MASTER_KEY` | 是 | 無 | LiteLLM Proxy 的 master key，Open WebUI 用它當 OpenAI API key |
| `PORT` | 否 | `8080` | Open WebUI 監聽的 port，host 網路下就是主機的 port |

```env
# .env 範例
LITELLM_MASTER_KEY=你的金鑰
PORT=8080
```

修改後重新執行 `./start_webui.sh` 即可套用。

其他設定直接修改 `docker/docker-compose.yaml`：

| 想調整的項目 | 修改方式 |
| --- | --- |
| LiteLLM 位址 | 修改 `OPENAI_API_BASE_URLS`（預設 `http://127.0.0.1:4000/v1`） |
| 映像版本 | 把 `image` 的 `main` 改成特定版本，版本清單見 [Releases](https://github.com/open-webui/open-webui/releases) |

> `OPENAI_API_BASE_URLS`、`OPENAI_API_KEYS`、`ENABLE_OLLAMA_API` 只在第一次啟動（全新的資料 volume）時讀取。之後，或沿用舊的資料 volume 時，這些連線設定要到 Open WebUI 的 Admin Settings > Connections 修改，改環境變數不會生效。因此更換 `LITELLM_MASTER_KEY` 後，也要到那裡同步更新。

## 常用指令

容器名稱固定為 `open-webui`，多數操作直接用 `docker` 即可：

```bash
docker ps --filter name=open-webui   # 服務狀態
docker logs -f open-webui            # 即時 log
docker restart open-webui            # 重啟服務
docker stop open-webui               # 停止服務（保留容器與資料）
```

移除容器需要用 compose，請在專案根目錄執行：

```bash
docker compose --project-directory . -f docker/docker-compose.yaml down
```

> 不要對 `down` 加 `-v`，那會連同資料 volume 一起刪除。

> 不要直接在 `docker/` 目錄裡執行 `docker compose`。compose 的 project 名稱會變成 `docker`，因此會建立另一個全新的資料 volume（`docker_open-webui`），而且讀不到根目錄的 `.env`。

更新到最新版：重新執行 `./start_webui.sh`。

## 疑難排解

**Open WebUI 看不到任何模型**

容器與主機共用網路，直接在主機上確認 LiteLLM 是否正常：

```bash
curl -s http://127.0.0.1:4000/v1/models -H "Authorization: Bearer 你的金鑰"
```

- 沒有回應：LiteLLM Proxy 沒有在運行，或不在 4000 port。
- 回傳 401：金鑰與 LiteLLM 的 master key 不一致。
- 有回傳模型清單卻仍看不到：若沿用舊的資料 volume，請到 Admin Settings > Connections 檢查連線設定，見上方「設定」的說明。

**出現 `The "LITELLM_MASTER_KEY" variable is not set`**

compose 沒讀到金鑰，服務仍會以空白金鑰啟動，之後連 LiteLLM 會被拒絕。確認 `.env` 在專案根目錄，且有 `LITELLM_MASTER_KEY=...` 這一行。

**第一次啟動很久**

第一次啟動需要初始化資料庫並載入內建模型，會比平常慢。腳本最多等 5 分鐘，可用 `docker logs -f open-webui` 查看進度。

**服務 port 已被占用**

host 網路會直接使用主機的 port（預設 8080）。用 `ss -ltnp | grep :8080` 找出占用的程式，或在 `.env` 設定 `PORT` 換一個 port，再重新執行 `./start_webui.sh`。

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

## 授權

[MIT License](LICENSE)
