"use server";

import { NDLSearchApiClient } from "../../../_lib/ndl-search-api-client";

const ndlSearchApiClient = new NDLSearchApiClient();

export async function searchBooks(titleSubStr: string) {
  const books = await ndlSearchApiClient.search(titleSubStr);
  return books;
}
