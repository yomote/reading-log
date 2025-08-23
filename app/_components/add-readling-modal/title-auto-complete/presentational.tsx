import React, { useState, useEffect, useMemo } from "react";
import Autocomplete from "@mui/material/Autocomplete";
import TextField from "@mui/material/TextField";
import CircularProgress from "@mui/material/CircularProgress";
import { debounce } from "@mui/material/utils";
import { searchBooks } from "./actions";
import { Book } from "../../../types";

interface TitleAutoCompleteProps {
  value?: string;
  onChange?: (value: string) => void;
  onBookSelect?: (book: Book) => void; // 選択された本の詳細情報を渡すためのコールバック
  onBlur?: () => void;
  name?: string;
}

export function TitleAutoComplete({
  value,
  onChange,
  onBookSelect,
  onBlur,
  name,
}: TitleAutoCompleteProps) {
  const [options, setOptions] = useState<Book[]>([]);
  const [loading, setLoading] = useState(false);
  const [inputValue, setInputValue] = useState(value || "");
  const [selectedBook, setSelectedBook] = useState<Book | null>(null);

  // valueプロパティが変更されたらinputValueを同期
  useEffect(() => {
    setInputValue(value || "");
    // 外部からのvalue変更時は選択状態をクリア
    if (!value) {
      setSelectedBook(null);
    }
  }, [value]);

  // デバウンス付きの検索関数
  const fetchBooks = useMemo(
    () =>
      debounce(async (query: string) => {
        if (query.trim().length < 2) {
          setOptions([]);
          setLoading(false);
          return;
        }
        setLoading(true);
        try {
          const books = await searchBooks(query);
          setOptions(books);
        } catch {
          setOptions([]);
        } finally {
          setLoading(false);
        }
      }, 500),
    []
  );

  useEffect(() => {
    fetchBooks(inputValue);
    return () => {
      fetchBooks.clear();
    };
  }, [inputValue, fetchBooks]);

  return (
    <Autocomplete
      id="book-search"
      options={options}
      value={selectedBook} // 選択された本を保持
      inputValue={inputValue}
      onChange={(_, newValue) => {
        if (newValue && typeof newValue === "object") {
          // 選択された本のタイトルを設定
          setSelectedBook(newValue);
          setInputValue(newValue.title);
          if (onChange) {
            onChange(newValue.title); // 選択された本のタイトルをformに渡す
          }
          if (onBookSelect) {
            onBookSelect(newValue); // 選択された本の詳細情報を親コンポーネントに渡す
          }
        } else if (newValue === null) {
          // 選択がクリアされた場合
          setSelectedBook(null);
          setInputValue("");
          if (onChange) {
            onChange("");
          }
        }
      }}
      onInputChange={(_, newInput) => {
        setInputValue(newInput);
        if (onChange) {
          onChange(newInput); // 入力値の変更もformに渡す
        }
      }}
      onBlur={onBlur}
      getOptionLabel={(option) => {
        return option.title || "";
      }}
      getOptionKey={(option) => {
        return option.id;
      }}
      isOptionEqualToValue={(option, v) => {
        return option.id === v?.id;
      }}
      loading={loading}
      noOptionsText={
        loading ? "検索中..." : "該当する書籍は見つかりませんでした"
      }
      loadingText="検索中..."
      filterOptions={(options) => options}
      renderInput={(params) => (
        <TextField
          {...params}
          name={name}
          label="書籍タイトルを検索"
          margin="dense"
          fullWidth
          variant="standard"
          slotProps={{
            input: {
              ...params.InputProps,
              endAdornment: (
                <React.Fragment>
                  {loading ? (
                    <CircularProgress color="inherit" size={20} />
                  ) : null}
                  {params.InputProps.endAdornment}
                </React.Fragment>
              ),
            },
          }}
        />
      )}
    />
  );
}
