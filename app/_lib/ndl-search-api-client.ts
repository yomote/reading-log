import { JSDOM } from "jsdom";
import { Book } from "../types";

/**
 * 国立国会図書館サーチAPIクライアント
 * APIの概要：https://ndlsearch.ndl.go.jp/help/api/specifications
 */
export class NDLSearchApiClient {
  private readonly baseURL: string;
  private readonly domParser: DOMParser;

  constructor() {
    this.baseURL = "https://ndlsearch.ndl.go.jp";
    const { window } = new JSDOM();
    this.domParser = new window.DOMParser();
  }

  async search(titleSubStr: string): Promise<Book[]> {
    const responseText = await fetch(
      `${this.baseURL}/api/opensearch?cnt=10&title=${encodeURIComponent(
        titleSubStr
      )}`
    ).then((res) => res.text());

    const xmlDoc = this.domParser.parseFromString(responseText, "text/xml");
    return Array.from(xmlDoc.querySelectorAll("item"))
      .map((item) => {
        const identifiers = Array.from(item.getElementsByTagName("*")).filter(
          (element) => element.tagName.includes("identifier")
        );
        const ndlIdentifier = identifiers.find(
          (identifier) =>
            identifier.getAttribute("xsi:type") === "dcndl:NDLBibID"
        );
        const isbnIdentifier = identifiers.find(
          (identifier) => identifier.getAttribute("xsi:type") === "dcndl:ISBN"
        );
        const jpnoIdentifier = identifiers.find(
          (identifier) => identifier.getAttribute("xsi:type") === "dcndl:JPNO"
        );

        return {
          id: ndlIdentifier?.textContent || "",
          title: item.querySelector("title")?.textContent || "",
          author: item.querySelector("author")?.textContent || "",
          link: item.querySelector("link")?.textContent || "",
          publishedDate: item.querySelector("pubDate")?.textContent || "",
          isbn: (isbnIdentifier?.textContent || "").replace(/-/g, ""),
          jpno: jpnoIdentifier?.textContent || "",
        };
      })
      .filter((book) => book.id.trim() !== ""); // idが空でない書籍のみを返す
  }
}
