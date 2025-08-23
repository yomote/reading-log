"use client";

import {
  Button,
  Card,
  CardActions,
  CardContent,
  CardMedia,
  IconButton,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from "@mui/material";
import TrashIcon from "@mui/icons-material/Delete";
import EditIcon from "@mui/icons-material/Edit";
import { Reading } from "@prisma/client";
import NiceModal from "@ebay/nice-modal-react";
import { DeleteReadingModalPresentation } from "../delete-reading-modal";

export function ReadingListPresentation({
  readlings,
}: {
  readlings: Reading[];
}) {
  const showDeleteModal = (reading: Reading) => {
    NiceModal.show(DeleteReadingModalPresentation, { reading });
  };

  return (
    <NiceModal.Provider>
      {/* <Card>
        <CardMedia
          component="img"
          alt="green iguana"
          height="140"
          image="/static/images/cards/contemplative-reptile.jpg"
        />
        <CardContent>
          <Typography gutterBottom variant="h5" component="div">
            Lizard
          </Typography>
          <Typography variant="body2" sx={{ color: "text.secondary" }}>
            Lizards are a widespread group of squamate reptiles, with over 6,000
            species, ranging across all continents except Antarctica
          </Typography>
        </CardContent>
        <CardActions>
          <Button size="small">Share</Button>
          <Button size="small">Learn More</Button>
        </CardActions>
      </Card> */}
      <TableContainer component={Paper}>
        <Table>
          <TableHead sx={{ backgroundColor: "#0a54b4ff" }}>
            <TableRow>
              <TableCell sx={{ fontWeight: "bold", color: "#ffffff" }}>
                Title
              </TableCell>
              <TableCell sx={{ fontWeight: "bold", color: "#ffffff" }}>
                Author
              </TableCell>
              <TableCell
                sx={{ fontWeight: "bold", color: "#ffffff" }}
              ></TableCell>
              <TableCell
                sx={{ fontWeight: "bold", color: "#ffffff" }}
              ></TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {readlings.map((reading) => (
              <TableRow key={reading.id}>
                <TableCell>{reading.title}</TableCell>
                <TableCell>{reading.author}</TableCell>
                <TableCell>
                  {/* <IconButton
                  onClick={() =>
                    handleUpdate(reading.id, reading.title, reading.author)
                  }
                >
                  <EditIcon />
                </IconButton> */}
                </TableCell>
                <TableCell>
                  <IconButton onClick={() => showDeleteModal(reading)}>
                    <TrashIcon />
                  </IconButton>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>
    </NiceModal.Provider>
  );
}
