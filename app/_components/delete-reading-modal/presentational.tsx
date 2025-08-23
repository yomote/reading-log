"use client";

import {
  Box,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogContentText,
  DialogTitle,
  Grid,
  IconButton,
  TextField,
  Typography,
} from "@mui/material";
import CloseIcon from "@mui/icons-material/Close";
import { deleteReadling } from "./actions";
import NiceModal, { useModal } from "@ebay/nice-modal-react";
import { Reading } from "@prisma/client";

export const DeleteReadingModalPresentation = NiceModal.create(
  ({ reading }: { reading: Reading }) => {
    const modal = useModal();

    const handleDelete = () => {
      deleteReadling(reading.id);
      modal.hide();
    };

    return (
      <Dialog open={modal.visible} onClose={modal.hide}>
        <DialogTitle>Delete Reading</DialogTitle>
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
          <DialogContentText>
            To delete this reading, please confirm your action.
          </DialogContentText>

          <Grid container spacing={1} sx={{ mt: 3, mx: 3 }}>
            <Grid size={3}>
              <Typography variant="body1" sx={{ fontWeight: "bold" }}>
                Title
              </Typography>
            </Grid>
            <Grid size={9}>
              <Typography variant="body1">{reading.title}</Typography>
            </Grid>
            <Grid size={3}>
              <Typography variant="body1" sx={{ fontWeight: "bold" }}>
                Author
              </Typography>
            </Grid>
            <Grid size={9}>
              <Typography variant="body1">{reading.author}</Typography>
            </Grid>
          </Grid>
        </DialogContent>
        <DialogActions>
          <Button
            onClick={() => handleDelete()}
            color="error"
            variant="contained"
          >
            Delete
          </Button>
        </DialogActions>
      </Dialog>
    );
  }
);
