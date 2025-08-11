import { PrismaClient } from "@prisma/client";
const prisma = new PrismaClient();

async function main() {
  // 開発用途: 既存データをクリア
  await prisma.readling.deleteMany();

  // 初期データ投入
  await prisma.readling.createMany({
    data: [
      { title: "The Great Gatsby", author: "F. Scott Fitzgerald" },
      { title: "1984", author: "George Orwell" },
      { title: "To Kill a Mockingbird", author: "Harper Lee" },
    ],
  });

  const count = await prisma.readling.count();
  console.log(`Seeded ${count} readlings`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
