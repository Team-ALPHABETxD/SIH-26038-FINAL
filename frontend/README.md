# DR-xAI Next.js Frontend

Next.js frontend for the supplied MATLAB + Flask DR-xAI pipeline.

## Run

```bash
npm install
npm run dev
```

The frontend proxies `/api/*` to Flask at `http://127.0.0.1:5000` by default. To change it, create `.env.local` with:

```env
BACKEND_URL=http://127.0.0.1:5000
```

Open `http://localhost:3000`.

## Production

```bash
npm run build
npm start
```
