"use client";

import NiceModal from "@ebay/nice-modal-react";
import { Box, Typography, Fab } from "@mui/material";
import AddIcon from "@mui/icons-material/Add";
import { AddReadingModalPresentation } from "../add-readling-modal";

export function ContentHeaderPresentation() {
  const onAddClick = () => {
    NiceModal.show(AddReadingModalPresentation, {});
  };

  return (
    <NiceModal.Provider>
      <Box sx={{ m: 2, display: "flex", justifyContent: "space-between" }}>
        <Typography variant="h4" gutterBottom>
          Reading List
        </Typography>

        <Fab variant="extended" color="primary" onClick={onAddClick}>
          <AddIcon />
          Add Reading
        </Fab>
      </Box>
    </NiceModal.Provider>
  );
}
