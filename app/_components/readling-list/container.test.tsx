import { ReadingListContainer } from "./container";
import { ReadingListPresentation } from "./presentational";

const mockFindMany = jest.fn();
jest.mock("@prisma/client", () => ({
  PrismaClient: jest.fn().mockImplementation(() => ({
    reading: {
      findMany: mockFindMany,
    },
    $disconnect: jest.fn(),
  })),
}));

describe("DBからのデータ取得成功時", () => {
  test("ReadingListPresentationにDBからのデータが渡される", async () => {
    // Arrange
    const dummyData = [
      { id: 1, title: "Sample Reading 1", author: "Author 1" },
      { id: 2, title: "Sample Reading 2", author: "Author 2" },
    ];
    mockFindMany.mockResolvedValue(dummyData);

    // Act
    const sut = await ReadingListContainer();

    // Assert
    expect(sut.type).toBe(ReadingListPresentation);
    expect(sut.props.readlings).toEqual(dummyData);
  });
});

describe("DBからのデータ取得失敗時", () => {
  test("DB接続エラー時にエラーメッセージが表示される", async () => {
    // Arrange
    mockFindMany.mockRejectedValue(new Error("DB connection error"));

    // Act & Assert
    await expect(ReadingListContainer()).rejects.toThrow("DB connection error");
  });
});
