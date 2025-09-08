import React from "react";
import { render, screen, within } from "@testing-library/react";
import "@testing-library/jest-dom";
import userEvent from "@testing-library/user-event";
import { ReadingListPresentation } from "./presentational";

const mockDelete = jest.fn();
jest.mock("@prisma/client", () => ({
  PrismaClient: jest.fn().mockImplementation(() => ({
    reading: {
      delete: mockDelete,
    },
    $disconnect: jest.fn(),
  })),
}));

const user = userEvent.setup();

describe("書籍データが1件以上ある場合", () => {
  const oneOrMoreReadingsMock = [
    { id: 1, title: "Sample Reading 1", author: "Author 1" },
    { id: 2, title: "Sample Reading 2", author: "Author 2" },
  ];

  it("テーブルヘッダーが表示される", () => {
    // Arrange
    render(<ReadingListPresentation readlings={oneOrMoreReadingsMock} />);
    const table = screen.getByRole("table");

    // Act: なし

    // Assert
    expect(
      within(table).getByRole("columnheader", { name: "Title" })
    ).toBeInTheDocument();
    expect(
      within(table).getByRole("columnheader", { name: "Author" })
    ).toBeInTheDocument();
  });

  it("各書籍のタイトルと著者, 削除ボタンが表示される", () => {
    // Arrange
    render(<ReadingListPresentation readlings={oneOrMoreReadingsMock} />);
    const tableRows = within(screen.getByRole("table"))
      .getAllByRole("row")
      .slice(1); // ヘッダー行を除外

    // Act: なし

    // Assert
    expect(tableRows).toHaveLength(oneOrMoreReadingsMock.length);
    tableRows.forEach((row, index) => {
      expect(row).toHaveTextContent(oneOrMoreReadingsMock[index].title);
      expect(row).toHaveTextContent(oneOrMoreReadingsMock[index].author);
      expect(
        within(row).getByRole("button", { name: "show-delete-modal" })
      ).toBeInTheDocument();
    });
  });

  it("一行目の削除ボタンを押下すると、削除モーダルが表示される", async () => {
    // Arrange
    render(<ReadingListPresentation readlings={oneOrMoreReadingsMock} />);
    const firstTableRow = within(screen.getByRole("table")).getAllByRole(
      "row"
    )[1]; // ヘッダー行の次の行
    const deleteButton = within(firstTableRow).getByRole("button", {
      name: "show-delete-modal",
    });

    // Act
    await user.click(deleteButton);

    // Assert
    expect(screen.getByRole("dialog")).toHaveTextContent("Delete Reading");
  });
});
