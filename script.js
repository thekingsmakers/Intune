// Tabs Functionality
const tabButtons = document.querySelectorAll('.tab-button');
const tabPanes = document.querySelectorAll('.tab-pane');

tabButtons.forEach(button => {
    button.addEventListener('click', () => {
        const targetTab = button.getAttribute('data-tab');
        tabButtons.forEach(btn => btn.classList.remove('active'));
        tabPanes.forEach(pane => pane.classList.remove('active'));
        button.classList.add('active');
        document.getElementById(targetTab).classList.add('active');
    });
});

// Copy Command Functionality
function copyCommand(id) {
    const copyText = document.getElementById(id).innerText;
    navigator.clipboard.writeText(copyText)
        .then(() => alert("Copied to clipboard!"))
        .catch(err => console.error('Failed to copy:', err));
}

// Clock Functionality
function updateClock() {
    const now = new Date();
    document.getElementById('clock').textContent = now.toLocaleTimeString();
}
setInterval(updateClock, 1000);
updateClock();

// Theme Toggle Functionality
const themeToggle = document.getElementById('themeToggle');
const themeLabel = document.getElementById('themeLabel');

themeToggle.addEventListener('change', function() {
    document.body.classList.toggle('light-mode');
    themeLabel.textContent = document.body.classList.contains('light-mode') ? 'Dark Mode' : 'Light Mode';
});

// Chatbot Functionality
const chatbotPopup = document.getElementById('chatbotPopup');
const chatbotToggle = document.getElementById('chatbotToggle');
const closeChatbot = document.getElementById('closeChatbot');
const chatMessages = document.getElementById('chatMessages');
const chatInput = document.getElementById('chatInput');
const sendMessageBtn = document.getElementById('sendMessage');

let userName = null;
let userEmail = null;

// Open Chatbot
chatbotToggle.addEventListener('click', () => {
    chatbotPopup.classList.add('active');
    if (!userName) {
        appendBotMessage("Hello! What's your name?");
    }
});

// Close Chatbot
closeChatbot.addEventListener('click', () => {
    chatbotPopup.classList.remove('active');
});

// Send Message
sendMessageBtn.addEventListener('click', () => {
    const userMessage = chatInput.value.trim();
    if (userMessage) {
        appendUserMessage(userMessage);
        chatInput.value = '';
        handleUserMessage(userMessage);
    }
});

// Handle User Input
function handleUserMessage(message) {
    if (!userName) {
        userName = message;
        appendBotMessage(`Nice to meet you, ${userName}! What's your email address?`);
    } else if (!userEmail) {
        userEmail = message;
        appendBotMessage(`Got it! How can I assist you today, ${userName}?`);
        chatInput.disabled = false;
    } else {
        appendBotMessage("I'm just a simple bot. If you need further assistance, please email me at redomarjobs@gmail.com.");
    }
}

// Append User Message
function appendUserMessage(message) {
    const p = document.createElement('p');
    p.textContent = message;
    chatMessages.appendChild(p);
    chatMessages.scrollTop = chatMessages.scrollHeight;
}

// Append Bot Message
function appendBotMessage(message) {
    const p = document.createElement('p');
    p.textContent = message;
    p.classList.add('bot-message');
    chatMessages.appendChild(p);
    chatMessages.scrollTop = chatMessages.scrollHeight;
}