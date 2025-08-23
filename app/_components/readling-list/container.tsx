import { PrismaClient } from "@prisma/client";
import { ReadingListPresentation } from "./presentational";

async function getReadlings() {
  const prisma = new PrismaClient();

  try {
    return await prisma.reading.findMany();
  } finally {
    await prisma.$disconnect();
  }
}

export async function ReadingListContainer() {
  const readlings = await getReadlings();

  return <ReadingListPresentation readlings={readlings} />;
}
