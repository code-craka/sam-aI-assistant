import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var appState: AppState
    @StateObject private var chatManager = ChatManager()
    @State private var showingAbout = false
    @State private var showingWorkflows = false
    @State private var selectedTab: MainTab = .chat
    
    enum MainTab: String, CaseIterable {
        case chat = "Chat"
        case workflows = "Workflows"
        
        var icon: String {
            switch self {
            case .chat:
                return "message"
            case .workflows:
                return "gearshape.2"
            }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Chat Interface
            NavigationSplitView(columnVisibility: $appState.sidebarVisibility) {
                // Sidebar - Chat History
                SidebarView()
                    .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
                    .environmentObject(chatManager)
            } detail: {
                // Main Chat Interface
                ChatView()
                    .environmentObject(chatManager)
            }
            .tabItem {
                Label("Chat", systemImage: "message")
            }
            .tag(MainTab.chat)
            
            // Workflow Management
            WorkflowView()
                .tabItem {
                    Label("Workflows", systemImage: "gearshape.2")
                }
                .tag(MainTab.workflows)
        }
        .navigationTitle(selectedTab == .chat ? appState.windowTitle : "Workflow Manager")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if selectedTab == .chat {
                    Button(action: {
                        Task {
                            await chatManager.startNewConversation()
                        }
                    }) {
                        Image(systemName: "plus.message")
                    }
                    .help("New Chat")
                    .accessibilityLabel("Start new chat")
                    
                    Button(action: {
                        appState.toggleSidebar()
                    }) {
                        Image(systemName: "sidebar.left")
                    }
                    .help("Toggle Sidebar")
                    .accessibilityLabel("Toggle sidebar visibility")
                }
                
                Button(action: {
                    appState.openSettings()
                }) {
                    Image(systemName: "gear")
                }
                .help("Settings")
                .accessibilityLabel("Open settings")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newChatRequested)) { _ in
            Task {
                await chatManager.startNewConversation()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearChatRequested)) { _ in
            Task {
                await chatManager.clearHistory()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebarRequested)) { _ in
            appState.toggleSidebar()
        }
        .onReceive(NotificationCenter.default.publisher(for: .aboutRequested)) { _ in
            showingAbout = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToWorkflowsRequested)) { _ in
            selectedTab = .workflows
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sam AI Assistant main interface")
    }
}

struct SidebarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var chatManager: ChatManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // New Chat Button
            Button(action: {
                chatManager.startNewConversation()
            }) {
                HStack {
                    Image(systemName: "plus.message")
                        .accessibilityHidden(true)
                    Text("New Chat")
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start new chat conversation")
            .keyboardShortcut("n", modifiers: [.command])
            
            Divider()
            
            // Chat History
            VStack(alignment: .leading, spacing: 4) {
                Text("Recent Chats")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .accessibilityAddTraits(.isHeader)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        // TODO: Implement chat history list from Core Data
                        if chatManager.messages.isEmpty {
                            Text("No previous chats")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        } else {
                            ChatHistoryItem(
                                title: "Current Chat",
                                messageCount: chatManager.messages.count,
                                isActive: true
                            )
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
            
            Spacer()
            
            // Quick Actions
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Actions")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .accessibilityAddTraits(.isHeader)
                
                QuickActionButton(
                    icon: "folder",
                    title: "File Operations",
                    action: "Help me with file operations"
                )
                QuickActionButton(
                    icon: "info.circle",
                    title: "System Info",
                    action: "Show me system information"
                )
                QuickActionButton(
                    icon: "app.badge",
                    title: "App Control",
                    action: "Help me control applications"
                )
                WorkflowQuickActionButton()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sidebar with chat history and quick actions")
    }
}

struct ChatHistoryItem: View {
    let title: String
    let messageCount: Int
    let isActive: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(isActive ? .semibold : .regular)
                    .lineLimit(1)
                
                Text("\(messageCount) messages")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isActive {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
                    .accessibilityLabel("Active chat")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(messageCount) messages\(isActive ? ", active" : "")")
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: String
    let customAction: (() -> Void)?
    @EnvironmentObject private var chatManager: ChatManager
    
    init(icon: String, title: String, action: String, customAction: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.action = action
        self.customAction = customAction
    }
    
    var body: some View {
        Button(action: {
            if let customAction = customAction {
                customAction()
            } else {
                Task {
                    await chatManager.sendMessage(action)
                }
            }
        }) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 16)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.caption)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
        .accessibilityLabel("Quick action: \(title)")
        .help(customAction != nil ? title : "Send: \(action)")
    }
}

struct WorkflowQuickActionButton: View {
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        Button(action: {
            // Switch to workflows tab - we'll need to pass this through the environment
            NotificationCenter.default.post(name: .switchToWorkflowsRequested, object: nil)
        }) {
            HStack {
                Image(systemName: "gearshape.2")
                    .frame(width: 16)
                    .accessibilityHidden(true)
                Text("Workflows")
                    .font(.caption)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
        .accessibilityLabel("Quick action: Workflows")
        .help("Open Workflow Manager")
    }
}

struct ChatView: View {
    @EnvironmentObject private var chatManager: ChatManager
    @EnvironmentObject private var appState: AppState
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages Area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if chatManager.messages.isEmpty && chatManager.streamingMessage == nil {
                            WelcomeView()
                        } else {
                            ForEach(chatManager.messages.filter { !$0.isDeleted }) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }
                            
                            // Show typing indicator
                            if chatManager.typingIndicator.isVisible {
                                TypingIndicatorBubble(indicator: chatManager.typingIndicator)
                                    .id("typing-indicator")
                            }
                            
                            // Show streaming message
                            if let streamingMessage = chatManager.streamingMessage {
                                StreamingMessageView(streamingMessage: streamingMessage)
                                    .id(streamingMessage.id)
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: chatManager.messages.count) { _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: chatManager.streamingMessage?.id) { _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: chatManager.typingIndicator.isVisible) { _ in
                    if chatManager.typingIndicator.isVisible {
                        scrollToBottom(proxy: proxy)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Chat messages")
            }
            
            Divider()
            
            // Input Area
            ChatInputView(
                text: $inputText,
                isProcessing: $chatManager.isProcessing,
                isInputFocused: $isInputFocused,
                onSend: { message in
                    Task {
                        await chatManager.sendMessage(message)
                        inputText = ""
                    }
                }
            )
        }
        .background(Color(NSColor.controlBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: .focusChatInputRequested)) { _ in
            isInputFocused = true
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chat interface")
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        let animation = appState.reduceMotion ? Animation.none : Animation.easeOut(duration: 0.3)
        withAnimation(animation) {
            if let streamingMessage = chatManager.streamingMessage {
                proxy.scrollTo(streamingMessage.id, anchor: UnitPoint.bottom)
            } else if chatManager.typingIndicator.isVisible {
                proxy.scrollTo("typing-indicator", anchor: UnitPoint.bottom)
            } else if let lastMessage = chatManager.messages.last {
                proxy.scrollTo(lastMessage.id, anchor: UnitPoint.bottom)
            }
        }
    }
}

struct TypingIndicatorBubble: View {
    let indicator: ChatModels.TypingIndicator
    @Environment(\.colorScheme) private var colorScheme
    
    private var bubbleBackgroundColor: Color {
        colorScheme == .dark 
            ? Color(NSColor.controlBackgroundColor).opacity(0.8)
            : Color(NSColor.controlBackgroundColor)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .padding(.top, 2)
                        .accessibilityHidden(true)
                    
                    HStack(spacing: 8) {
                        TypingIndicatorView()
                        Text(indicator.message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(bubbleBackgroundColor)
                    .cornerRadius(18)
                }
            }
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(indicator.message)
    }
}

struct WelcomeView: View {
    @EnvironmentObject private var chatManager: ChatManager
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
                .accessibilityLabel("Sam AI Assistant icon")
            
            VStack(spacing: 12) {
                Text("Welcome to Sam")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Your intelligent macOS assistant")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Try asking me to:")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                
                ExampleCommand(
                    text: "Copy file.pdf to Desktop",
                    action: { Task { await chatManager.sendMessage("Copy file.pdf to Desktop") } }
                )
                ExampleCommand(
                    text: "What's my battery level?",
                    action: { Task { await chatManager.sendMessage("What's my battery level?") } }
                )
                ExampleCommand(
                    text: "Open Safari and go to apple.com",
                    action: { Task { await chatManager.sendMessage("Open Safari and go to apple.com") } }
                )
                ExampleCommand(
                    text: "Organize my Downloads folder",
                    action: { Task { await chatManager.sendMessage("Organize my Downloads folder") } }
                )
            }
            .padding()
            .background(Color.accentColor.opacity(0.05))
            .cornerRadius(12)
        }
        .frame(maxWidth: 400)
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Welcome screen with example commands")
    }
}

struct ExampleCommand: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .accessibilityHidden(true)
                Text(text)
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Example command: \(text)")
        .accessibilityHint("Tap to send this command to Sam")
        .help("Send: \(text)")
    }
}

struct MessageBubbleView: View {
    let message: ChatModels.ChatMessage
    @EnvironmentObject private var chatManager: ChatManager
    @State private var isEditing = false
    @State private var editText = ""
    
    var body: some View {
        HStack {
            if message.isUserMessage {
                Spacer()
                UserMessageBubble(
                    message: message,
                    isEditing: $isEditing,
                    editText: $editText,
                    onEdit: { newContent in
                        Task {
                            await chatManager.editMessage(message.id, newContent: newContent)
                        }
                    },
                    onDelete: {
                        Task {
                            await chatManager.deleteMessage(message.id)
                        }
                    }
                )
            } else {
                AssistantMessageBubble(
                    message: message,
                    onDelete: {
                        Task {
                            await chatManager.deleteMessage(message.id)
                        }
                    }
                )
                Spacer()
            }
        }
        .opacity(message.isDeleted ? 0.3 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: message.isDeleted)
    }
}

struct StreamingMessageView: View {
    let streamingMessage: ChatModels.StreamingMessage
    @Environment(\.colorScheme) private var colorScheme
    
    private var bubbleBackgroundColor: Color {
        colorScheme == .dark 
            ? Color(NSColor.controlBackgroundColor).opacity(0.8)
            : Color(NSColor.controlBackgroundColor)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .padding(.top, 2)
                        .accessibilityHidden(true)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        if !streamingMessage.content.isEmpty {
                            Text(streamingMessage.content)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(bubbleBackgroundColor)
                                .cornerRadius(18)
                                .frame(maxWidth: 300, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        
                        // Streaming state indicator
                        StreamingStateView(streamingMessage: streamingMessage)
                    }
                }
                
                HStack {
                    Text(streamingMessage.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if streamingMessage.progress > 0 && streamingMessage.progress < 1 {
                        Text("• \(Int(streamingMessage.progress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.leading, 24)
            }
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sam is responding: \(streamingMessage.content)")
    }
}

struct StreamingStateView: View {
    let streamingMessage: ChatModels.StreamingMessage
    
    var body: some View {
        HStack(spacing: 8) {
            switch streamingMessage.streamingState {
            case .preparing:
                ProgressView()
                    .scaleEffect(0.6)
                Text("Preparing...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
            case .streaming:
                TypingIndicatorView()
                
            case .processing:
                ProgressView()
                    .scaleEffect(0.6)
                Text("Processing...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
            case .completing:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("Complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
            case .complete:
                EmptyView()
                
            case .error(let errorMessage):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
                Text("Error: \(errorMessage)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct TypingIndicatorView: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 6, height: 6)
                    .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: animationPhase
                    )
            }
        }
        .onAppear {
            animationPhase = 0
            withAnimation {
                animationPhase = 2
            }
        }
        .accessibilityLabel("Typing indicator")
    }
}

struct UserMessageBubble: View {
    let message: ChatModels.ChatMessage
    @Binding var isEditing: Bool
    @Binding var editText: String
    let onEdit: (String) -> Void
    let onDelete: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingContextMenu = false
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if isEditing {
                EditableMessageView(
                    text: $editText,
                    onSave: { newContent in
                        onEdit(newContent)
                        isEditing = false
                    },
                    onCancel: {
                        isEditing = false
                        editText = message.content
                    }
                )
            } else {
                HStack {
                    Text(message.content)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(18)
                        .frame(maxWidth: 300, alignment: .trailing)
                        .textSelection(.enabled)
                        .contextMenu {
                            Button("Edit") {
                                editText = message.content
                                isEditing = true
                            }
                            Button("Delete", role: .destructive) {
                                onDelete()
                            }
                        }
                }
            }
            
            HStack(spacing: 4) {
                if message.isEdited {
                    Text("edited")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your message: \(message.content)\(message.isEdited ? " (edited)" : "")")
        .accessibilityHint("Sent at \(message.timestamp.formatted(date: .omitted, time: .shortened))")
    }
}

struct EditableMessageView: View {
    @Binding var text: String
    let onSave: (String) -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            TextField("Edit message", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .focused($isFocused)
                .frame(maxWidth: 300)
            
            HStack(spacing: 8) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                
                Button("Save") {
                    onSave(text)
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}

struct AssistantMessageBubble: View {
    let message: ChatModels.ChatMessage
    let onDelete: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    private var bubbleBackgroundColor: Color {
        colorScheme == .dark 
            ? Color(NSColor.controlBackgroundColor).opacity(0.8)
            : Color(NSColor.controlBackgroundColor)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(bubbleBackgroundColor)
                    .cornerRadius(18)
                    .frame(maxWidth: 300, alignment: .leading)
                    .textSelection(.enabled)
                    .contextMenu {
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.content, forType: .string)
                        }
                        Button("Delete", role: .destructive) {
                            onDelete()
                        }
                    }
            }
            
            HStack {
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if message.executionTime > 0 {
                    Text("• \(String(format: "%.1fs", message.executionTime))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if message.tokens > 0 {
                    Text("• \(message.tokens) tokens")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if let taskType = message.taskType {
                    Text("• \(taskType.displayName)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.leading, 24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sam's response: \(message.content)")
        .accessibilityHint("Responded at \(message.timestamp.formatted(date: .omitted, time: .shortened))\(message.executionTime > 0 ? ", took \(String(format: "%.1f", message.executionTime)) seconds" : "")")
    }
}

struct ChatInputView: View {
    @Binding var text: String
    let isProcessing: Bool
    var isInputFocused: FocusState<Bool>.Binding
    let onSend: (String) -> Void
    @EnvironmentObject private var chatManager: ChatManager
    
    var body: some View {
        VStack(spacing: 8) {
            // Progress indicator
            if isProcessing && chatManager.processingProgress > 0 {
                ProgressView(value: chatManager.processingProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding(.horizontal)
            }
            
            HStack(spacing: 12) {
                TextField("Ask Sam anything...", text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                    .focused(isInputFocused)
                    .onSubmit {
                        sendMessage()
                    }
                    .disabled(isProcessing)
                    .accessibilityLabel("Message input field")
                    .accessibilityHint("Type your message to Sam here")
                
                Button(action: sendMessage) {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 16, height: 16)
                            .accessibilityLabel("Processing message")
                    } else {
                        Image(systemName: "paperplane.fill")
                            .accessibilityLabel("Send message")
                    }
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                .keyboardShortcut(.return, modifiers: [.command])
                .help(isProcessing ? "Processing..." : "Send message (⌘↩)")
            }
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Message input area")
    }
    
    private func sendMessage() {
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty && !isProcessing else { return }
        
        onSend(message)
    }
}



#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}