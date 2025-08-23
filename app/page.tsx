// app/page.tsx
import { Box } from "@mui/material";
import { ReadingListContainer } from "./_components/readling-list";
import { HomeNavBar } from "./navbar";
import { ContentHeaderPresentation } from "./_components/content-header";

export default async function Home() {
  return (
    <Box>
      <HomeNavBar />
      <Box
        sx={{
          mt: 2,
          p: 2,
          border: "1px solid #ccc",
          backgroundColor: "#f9f9f9",
          minHeight: "500px", // Adjust for AppBar height
        }}
      >
        <ContentHeaderPresentation />
        <ReadingListContainer />
      </Box>
    </Box>
  );
}
