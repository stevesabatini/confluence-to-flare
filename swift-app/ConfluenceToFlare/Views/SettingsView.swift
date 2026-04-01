import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = SettingsViewModel()

    var body: some View {
        Form {
            // MARK: - Confluence Connection
            Section("Confluence Connection") {
                TextField("Base URL", text: $vm.baseURL, prompt: Text("https://your-site.atlassian.net"))
                    .textContentType(.URL)

                TextField("Email", text: $vm.email, prompt: Text("your-email@company.com"))
                    .textContentType(.emailAddress)

                HStack {
                    if vm.showToken {
                        TextField("API Token", text: $vm.apiToken, prompt: Text("Your Confluence API token"))
                    } else {
                        SecureField("API Token", text: $vm.apiToken, prompt: Text("Your Confluence API token"))
                    }
                    Button(vm.showToken ? "Hide" : "Show") {
                        vm.showToken.toggle()
                    }
                    .buttonStyle(.borderless)
                }

                TextField("Production Parent Page ID", text: $vm.parentPageID, prompt: Text("139330809"))

                HStack {
                    Button("Test Connection") {
                        vm.testConnection()
                    }
                    .disabled(!vm.isValid || vm.isTesting)

                    if vm.isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                    }

                    if !vm.testConnectionStatus.isEmpty {
                        Text(vm.testConnectionStatus)
                            .font(.callout)
                            .foregroundStyle(
                                vm.testConnectionStatus.starts(with: "Connected") ? .green : .red
                            )
                    }
                }
            }

            // MARK: - Flare Project
            Section("Flare Project") {
                HStack {
                    TextField("Project Root", text: $vm.flareProjectRoot)
                        .truncationMode(.head)

                    Button("Choose...") {
                        vm.chooseFlareProject()
                    }
                }

                DisclosureGroup("Customize Paths", isExpanded: $vm.showAdvancedPaths) {
                    TextField("Release Notes Dir", text: $vm.releaseNotesDir)
                    TextField("Images Dir", text: $vm.imagesDir)
                    TextField("Overview File", text: $vm.overviewFile)
                    TextField("TOC File", text: $vm.tocFile)
                }
            }

            // MARK: - Save
            Section {
                HStack {
                    Button("Save Settings") {
                        vm.save()
                        appState.settings = AppSettings.load()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!vm.isValid)

                    if vm.isSaved {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 550, height: 520)
        .onAppear {
            vm.loadFromSettings()
        }
    }
}
