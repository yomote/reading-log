"use server";

import { PrismaClient } from "@prisma/client";
import { revalidateTag } from "next/cache";

export async function deleteReadling(id: string) {
  const prisma = new PrismaClient();

  try {
    await prisma.reading.delete({
      where: { id },
    });
    revalidateTag("readings");
  } finally {
    await prisma.$disconnect();
  }
}
