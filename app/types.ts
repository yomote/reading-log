/**
 * 国立国会図書館サーチAPIで取得できる書籍情報
 */
export type Book = {
  id: string;
  title: string;
  author: string;
  link: string;
  publishedDate: string;
  isbn: string;
  jpno: string;
};

export type ReadingStatus = "unread" | "reading" | "completed";
