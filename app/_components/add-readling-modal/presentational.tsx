"use client";

import {
  Box,
  Button,
  Dialog,
  DialogContent,
  DialogTitle,
  IconButton,
  TextField,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  Chip,
  Alert,
  Typography,
  List,
  ListItem,
  ListItemIcon,
  ListItemText,
} from "@mui/material";
import CloseIcon from "@mui/icons-material/Close";
import BookIcon from "@mui/icons-material/Book";
import MenuBookIcon from "@mui/icons-material/MenuBook";
import CheckCircleIcon from "@mui/icons-material/CheckCircle";
import InfoIcon from "@mui/icons-material/Info";
import { AddReadingFormData } from "./types";
import { Controller, useForm } from "react-hook-form";
import NiceModal, { useModal } from "@ebay/nice-modal-react";
import { TitleAutoComplete } from "./title-auto-complete";
import { Book } from "../../types";
import { createReading } from "./actions";

export const AddReadingModalPresentation = NiceModal.create(() => {
  const modal = useModal();

  const { handleSubmit, control, setValue } = useForm<AddReadingFormData>({
    defaultValues: {
      title: "",
      author: "",
      link: "",
      pubDate: "",
      isbn: "",
      jpno: "",
      status: "unread",
      note: "",
    },
  });

  // ステータス設定を配列で管理
  const statusOptions = [
    {
      value: "unread",
      label: "Unread",
      icon: BookIcon,
      color: "#757575",
      bgColor: "#f5f5f5",
    },
    {
      value: "reading",
      label: "Reading",
      icon: MenuBookIcon,
      color: "#2196f3",
      bgColor: "#e3f2fd",
    },
    {
      value: "read",
      label: "Read",
      icon: CheckCircleIcon,
      color: "#4caf50",
      bgColor: "#e8f5e8",
    },
  ];

  // 本が選択されたときに、他のフィールドにも値を自動入力
  const handleBookSelect = (book: Book) => {
    setValue("author", book.author);
    setValue("link", book.link);

    // publishedDateをYYYY-MM-DD形式に変換
    if (book.publishedDate) {
      try {
        const date = new Date(book.publishedDate);
        if (!isNaN(date.getTime())) {
          const formattedDate = date.toISOString().split("T")[0];
          setValue("pubDate", formattedDate);
        }
      } catch {
        console.warn("Invalid date format:", book.publishedDate);
      }
    }

    setValue("isbn", book.isbn);
    setValue("jpno", book.jpno);
  };

  const addReading = async (data: AddReadingFormData) => {
    createReading(data);
    modal.hide();
  };

  return (
    <Dialog
      fullWidth
      open={modal.visible}
      onClose={modal.hide}
      slotProps={{
        paper: { sx: { p: 2 } },
      }}
    >
      <DialogTitle>Add Reading</DialogTitle>
      <IconButton
        aria-label="close"
        onClick={modal.hide}
        sx={(theme) => ({
          position: "absolute",
          right: 8,
          top: 8,
          color: theme.palette.grey[500],
        })}
      >
        <CloseIcon />
      </IconButton>
      <DialogContent>
        <Alert severity="info" sx={{ mb: 2 }}>
          <Typography variant="body2" component="div">
            書籍タイトルを検索して選択すると、以下のフィールドが自動入力されます：
            <List dense sx={{ pl: 2 }}>
              <ListItem disablePadding>
                <ListItemIcon sx={{ minWidth: 20 }}>
                  <InfoIcon fontSize="small" color="primary" />
                </ListItemIcon>
                <ListItemText primary="著者・リンク・出版日・ISBN・JPNO" />
              </ListItem>
            </List>
            必要に応じて手動で編集することも可能です。
          </Typography>
        </Alert>

        <Box component="form" onSubmit={handleSubmit(addReading)}>
          <Controller
            name="title"
            control={control}
            render={({ field }) => (
              <TitleAutoComplete
                value={field.value}
                onChange={field.onChange}
                onBookSelect={handleBookSelect}
                onBlur={field.onBlur}
                name={field.name}
              />
            )}
          />
          <Controller
            name="author"
            control={control}
            render={({ field }) => (
              <TextField
                {...field}
                margin="dense"
                label="Author"
                type="text"
                fullWidth
                variant="standard"
              />
            )}
          />
          <Controller
            name="link"
            control={control}
            render={({ field }) => (
              <TextField
                {...field}
                margin="dense"
                label="Link"
                type="text"
                fullWidth
                variant="standard"
              />
            )}
          />
          <Controller
            name="pubDate"
            control={control}
            render={({ field }) => (
              <TextField
                {...field}
                margin="dense"
                label="Publication Date"
                type="date"
                fullWidth
                variant="standard"
                slotProps={{
                  inputLabel: { shrink: true },
                }}
              />
            )}
          />
          <Controller
            name="isbn"
            control={control}
            render={({ field }) => (
              <TextField
                {...field}
                margin="dense"
                label="ISBN"
                type="text"
                fullWidth
                variant="standard"
              />
            )}
          />
          <Controller
            name="jpno"
            control={control}
            render={({ field }) => (
              <TextField
                {...field}
                margin="dense"
                label="JPNO"
                type="text"
                fullWidth
                variant="standard"
              />
            )}
          />
          <Controller
            name="status"
            control={control}
            render={({ field }) => {
              const selectedStatus = statusOptions.find(
                (option) => option.value === field.value
              );
              return (
                <FormControl fullWidth margin="dense" variant="standard">
                  <InputLabel>Status</InputLabel>
                  <Select
                    {...field}
                    label="Status"
                    renderValue={() =>
                      selectedStatus && (
                        <Box
                          sx={{ display: "flex", alignItems: "center", gap: 1 }}
                        >
                          <selectedStatus.icon
                            sx={{ color: selectedStatus.color }}
                          />
                          <Chip
                            label={selectedStatus.label}
                            size="small"
                            sx={{
                              bgcolor: selectedStatus.bgColor,
                              color: selectedStatus.color,
                            }}
                          />
                        </Box>
                      )
                    }
                  >
                    {statusOptions.map((option) => (
                      <MenuItem key={option.value} value={option.value}>
                        <Box
                          sx={{ display: "flex", alignItems: "center", gap: 1 }}
                        >
                          <option.icon sx={{ color: option.color }} />
                          <span>{option.label}</span>
                        </Box>
                      </MenuItem>
                    ))}
                  </Select>
                </FormControl>
              );
            }}
          />
          <Controller
            name="note"
            control={control}
            render={({ field }) => (
              <TextField
                {...field}
                margin="dense"
                label="Note"
                fullWidth
                multiline
                rows={4}
                sx={{ mt: 2 }}
              />
            )}
          />
          <Button
            type="submit"
            variant="contained"
            sx={{ mt: 3, display: "block", ml: "auto" }}
          >
            Add
          </Button>
        </Box>
      </DialogContent>
    </Dialog>
  );
});
