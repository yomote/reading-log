import { AppBar, Toolbar, Typography } from "@mui/material";

export function HomeNavBar() {
  return (
    <AppBar position="static" enableColorOnDark>
      <Toolbar>
        <Typography variant="h6" sx={{ flexGrow: 1 }}>
          Reading Log
        </Typography>
      </Toolbar>
    </AppBar>
  );
}
