"use server";

import { PrismaClient } from "@prisma/client";
import { revalidateTag } from "next/cache";
import { AddReadingFormData } from "./types";

const prisma = new PrismaClient();

export async function createReading(data: AddReadingFormData) {
  const reading = await prisma.reading.create({
    data: {
      title: data.title,
      author: data.author,
      link: data.link ?? "",
      pubDate: data.pubDate ?? "",
      isbn: data.isbn,
      jpno: data.jpno,
      status: data.status || "unread",
      note: data.note || "",
    },
  });

  revalidateTag("readings");
  return reading;
}
