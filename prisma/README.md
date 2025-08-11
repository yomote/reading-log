# Prisma Tips

## ローカルでDB立てる

### 1. このディレクトリ(`reading-log/prisma`)でドッカー起動

```bash
docker compose up -d
```

### 2. このディレクトリ(`reading-log/prisma`)に`.env`ファイルを作成し、DB接続文字列を設定

```
DATABASE_URL="sqlserver://localhost:1433;database=content_log;user=SA;password=P@ssw0rd123!;encrypt=false;trustServerCertificate=true;"
```

### 3. Prismaスキーマ適用, Prismaクライアント作成

```bash
pnpm prisma migrate dev 
```

### (必要に応じて)初期データ投入

```bash
npm run db:seed
```
