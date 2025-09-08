// Learn more: https://github.com/testing-library/jest-dom
import "@testing-library/jest-dom";

import { TextEncoder, TextDecoder } from "util";
global.TextEncoder = TextEncoder;
global.TextDecoder = TextDecoder;

// Mock next/cache functions
jest.mock("next/cache", () => ({
  revalidateTag: jest.fn(),
  revalidatePath: jest.fn(),
}));
