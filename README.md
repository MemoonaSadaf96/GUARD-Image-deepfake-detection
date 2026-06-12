# Image Deepfake Detection — Ubuntu install

After you unzip this folder, open a terminal in the project directory and run:

```bash
cd "Image Deepfake Detection"
sed -i 's/\r$//' setup.sh start.sh scripts/*.sh
chmod +x setup.sh start.sh scripts/*.sh
./setup.sh --fresh
```

The `sed` line fixes Windows-style line endings if the zip was created on Windows (without it, `npm start` may show `$'\r': command not found`).

`setup.sh` will ask for your **sudo** password once. It installs everything needed on **Ubuntu 22.04** (or similar), including:

- exiftool, tesseract, ImageMagick, file, libmagic  
- Python 3 and a project virtualenv  
- Node.js 20 (if not already installed)  
- npm packages and Python packages  

### Configure API key

Edit the file `.env` in this folder and set:

```env
OPENAI_API_KEY=your_key_here
```

Optional (online checks): `SIGHTENGINE_API_USER` and `SIGHTENGINE_API_SECRET`.

### Start the app

```bash
npm start
```

Then open in your browser:

- **http://127.0.0.1:3000** — upload a JPG or PNG and click **Analyze**

The first full analysis can take **about 4–7 minutes** (many AI agents run on the server).
The packaged project now defaults TensorFlow to **CPU mode** for portability, which avoids the broken `0%` confidence case on PCs with CUDA/driver issues. If a PC has a fully working NVIDIA CUDA setup and you want to try GPU, set `FORCE_CPU_INFERENCE=0` in `.env`.

### Model weights

The zip should include `models/best_model_effatt.h5`. If that file is missing, copy your trained `.h5` file into the `models/` folder, or set `MODEL_REPO_ID` in `.env`.

### Moving the project to another PC (zip)

Do **not** copy the `.venv` folder from another machine — it is tied to that PC’s Python and GPU drivers. On the new PC:

1. Unzip the project and run `./setup.sh --fresh` (removes copied runtime folders and creates a fresh `.venv`).
2. Make sure `models/best_model_effatt.h5` is in the zip (it is large and easy to omit).
3. Set `OPENAI_API_KEY` in `.env` on the new machine.

CPU mode is now the default for portable copies. If the API log shows **`failed call to cuInit` / CUDA error 303**, keep this in `.env`:

```env
FORCE_CPU_INFERENCE=1
```

Then restart with `npm start`. TensorFlow will use CPU only (slower but more reliable across different PCs).

**Quick check on the new PC:**

```bash
source .venv/bin/activate
python scripts/verify-local-model.py /path/to/test.jpg
```

You should see confidence around 90%+ on a normal photo. If the **Local Model Agent** card shows an error or “failed to load”, the summary bar will be wrong until the model loads.

### Make a clean zip on your PC

Instead of zipping the whole folder manually, run:

```bash
cd "Image Deepfake Detection"
npm run zip:portable
```

This creates a clean zip next to the project folder and excludes `.venv`, `node_modules`, `frontend/.next`, `.git`, and `.env`, so the other PC rebuilds correctly.

### Stop the app

Press `Ctrl+C` in the terminal where `npm start` is running.
