import { PrismaClient } from "@prisma/client";
const prisma = new PrismaClient();

async function main() {
  // 開発用途: 既存データをクリア
  await prisma.reading.deleteMany();

  // 初期データ投入
  await prisma.reading.createMany({
    data: [
      {
        title: "The Great Gatsby",
        author: "F. Scott Fitzgerald",
        link: "https://example.com/gatsby",
        pubDate: "1925-04-10",
        isbn: "9780743273565",
        jpno: "1234567890",
        status: "unread",
        note: "A classic novel set in the 1920s.",
      },
      {
        title: "1984",
        author: "George Orwell",
        link: "https://example.com/1984",
        pubDate: "1949-06-08",
        isbn: "9780451524935",
        jpno: "0987654321",
        status: "reading",
        note: "A dystopian novel about totalitarianism.",
      },
      {
        title: "To Kill a Mockingbird",
        author: "Harper Lee",
        link: "https://example.com/mockingbird",
        pubDate: "1960-07-11",
        isbn: "9780061120084",
        jpno: "1122334455",
        status: "read",
        note: "A novel about racial injustice in the Deep South.",
      },
    ],
  });

  const count = await prisma.reading.count();
  console.log(`Seeded ${count} readings`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
