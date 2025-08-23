import { ReadingStatus } from "../../types";

export type AddReadingFormData = {
  title: string;
  author: string;
  link?: string;
  pubDate?: string;
  isbn?: string;
  jpno?: string;
  status?: ReadingStatus;
  note?: string;
};
