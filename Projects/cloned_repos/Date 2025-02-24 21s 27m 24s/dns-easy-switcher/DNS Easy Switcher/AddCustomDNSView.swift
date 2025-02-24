//
//  AddCustomDNSView.swift
//  DNS Easy Switcher
//
//  Created by Gregory LINFORD on 23/02/2025.
//

import SwiftUI
import SwiftData

struct AddCustomDNSView: View {
    @State private var name: String = ""
    @State private var primaryDNS: String = ""
    @State private var secondaryDNS: String = ""
    var onComplete: (CustomDNSServer?) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Name (e.g. Work DNS)", text: $name)
                .textFieldStyle(.roundedBorder)
            
            TextField("Primary DNS (e.g. 8.8.8.8)", text: $primaryDNS)
                .textFieldStyle(.roundedBorder)
            
            TextField("Secondary DNS (optional)", text: $secondaryDNS)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel") {
                    onComplete(nil)
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Add") {
                    guard !name.isEmpty && !primaryDNS.isEmpty else { return }
                    let server = CustomDNSServer(
                        name: name,
                        primaryDNS: primaryDNS,
                        secondaryDNS: secondaryDNS
                    )
                    onComplete(server)
                }
                .keyboardShortcut(.return)
                .disabled(name.isEmpty || primaryDNS.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}
