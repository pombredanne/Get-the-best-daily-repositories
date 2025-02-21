import { useState } from 'react';
import './App.css';
import { Container, CssBaseline, ThemeProvider, createTheme, Box, Tabs, Tab, Paper, Button, Typography } from '@mui/material';
import GitHubIcon from '@mui/icons-material/GitHub';
import { RecordForm } from './components/RecordForm';
import { StatsChart } from './components/StatsChart';
import { HistoryList } from './components/HistoryList';
import { UpdateDialog } from './components/UpdateDialog';

interface TabPanelProps {
  children?: React.ReactNode;
  index: number;
  value: number;
}

function TabPanel(props: TabPanelProps) {
  const { children, value, index, ...other } = props;

  return (
    <div
      role="tabpanel"
      hidden={value !== index}
      id={`simple-tabpanel-${index}`}
      aria-labelledby={`simple-tab-${index}`}
      {...other}
    >
      {value === index && (
        <Box sx={{ py: 3 }}>
          {children}
        </Box>
      )}
    </div>
  );
}

const theme = createTheme({
  typography: {
    fontFamily: [
      '思源黑体',
      'Noto Sans SC',
      '-apple-system',
      'BlinkMacSystemFont',
      '"Segoe UI"',
      'Roboto',
      '"Helvetica Neue"',
      'Arial',
      'sans-serif',
      '"Apple Color Emoji"',
      '"Segoe UI Emoji"',
      '"Segoe UI Symbol"'
    ].join(','),
  },
  palette: {
    primary: {
      main: '#2196f3',
      light: '#64b5f6',
      dark: '#1976d2',
    },
    error: {
      main: '#f44336',
      light: '#e57373',
      dark: '#d32f2f',
    },
    background: {
      default: '#f5f5f5',
      paper: '#ffffff',
    },
  },
  shape: {
    borderRadius: 12,
  },
  components: {
    MuiPaper: {
      styleOverrides: {
        root: {
          boxShadow: '0 2px 12px 0 rgba(0,0,0,0.1)',
        },
      },
    },
  },
});

function App() {
  const [tabValue, setTabValue] = useState(0);

  const handleTabChange = (_event: React.SyntheticEvent, newValue: number) => {
    setTabValue(newValue);
  };

  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <Box sx={{ minHeight: '100vh', backgroundColor: 'background.default' }}>
        <UpdateDialog />
        <Container maxWidth="md" sx={{ py: 4 }}>
          <Paper sx={{ p: 3 }}>
            <Box sx={{ borderBottom: 1, borderColor: 'divider', mb: 2 }}>
              <Tabs value={tabValue} onChange={handleTabChange} aria-label="basic tabs example">
                <Tab label="主页面" id="simple-tab-0" aria-controls="simple-tabpanel-0" />
                <Tab label="历史记录" id="simple-tab-1" aria-controls="simple-tabpanel-1" />
              </Tabs>
            </Box>

            <TabPanel value={tabValue} index={0}>
              {/* 添加 GitHub Star 按钮 */}
              <Box sx={{ 
                display: 'flex', 
                flexDirection: 'column', 
                alignItems: 'center', 
                gap: 1,
                mb: 4
              }}>
                <Typography
                  variant="subtitle2"
                  sx={{
                    color: 'text.secondary',
                    fontWeight: 500,
                    fontSize: '0.875rem'
                  }}
                >
                  祝愿所有给本项目Star的小伙伴牛子长度翻倍！
                </Typography>
                <Button
                  variant="contained"
                  color="primary"
                  startIcon={<GitHubIcon />}
                  onClick={() => window.open('https://github.com/zzzdajb/DickHelper', '_blank')}
                  sx={{
                    borderRadius: 2,
                    textTransform: 'none',
                    fontWeight: 600,
                    background: 'linear-gradient(45deg, #24292e 30%, #40464e 90%)',
                    '&:hover': {
                      background: 'linear-gradient(45deg, #40464e 30%, #586069 90%)',
                      transform: 'translateY(-2px)',
                      boxShadow: '0 4px 12px rgba(0,0,0,0.15)'
                    },
                    transition: 'all 0.3s ease'
                  }}
                >
                  ⭐ Star on GitHub
                </Button>
              </Box>

              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                <Box>
                  <RecordForm />
                </Box>
                <Box>
                  <StatsChart />
                </Box>
              </Box>
            </TabPanel>

            <TabPanel value={tabValue} index={1}>
              <HistoryList />
            </TabPanel>
          </Paper>
        </Container>
      </Box>
    </ThemeProvider>
  );
}

export default App;
