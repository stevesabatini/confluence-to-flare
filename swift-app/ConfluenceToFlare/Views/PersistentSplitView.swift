import SwiftUI
import AppKit

/// An NSSplitView wrapper that persists divider positions via autosaveName.
/// When the right panel is hidden, it is fully removed from the split view
/// so no divider remnant is visible.
struct PersistentSplitView<Left: View, Right: View>: NSViewRepresentable {
    let autosaveName: String
    let left: Left
    let right: Right
    let showRight: Bool

    init(
        autosaveName: String,
        showRight: Bool,
        @ViewBuilder left: () -> Left,
        @ViewBuilder right: () -> Right
    ) {
        self.autosaveName = autosaveName
        self.showRight = showRight
        self.left = left()
        self.right = right()
    }

    func makeNSView(context: Context) -> NSSplitView {
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .paneSplitter
        splitView.autosaveName = autosaveName
        splitView.delegate = context.coordinator

        let leftHost = NSHostingView(rootView: left)
        leftHost.widthAnchor.constraint(greaterThanOrEqualToConstant: 380).isActive = true

        let rightHost = NSHostingView(rootView: right)
        rightHost.widthAnchor.constraint(greaterThanOrEqualToConstant: 0).isActive = true

        context.coordinator.leftView = leftHost
        context.coordinator.rightView = rightHost

        splitView.addArrangedSubview(leftHost)

        if showRight {
            splitView.addArrangedSubview(rightHost)
        }

        return splitView
    }

    func updateNSView(_ splitView: NSSplitView, context: Context) {
        guard let leftHost = context.coordinator.leftView as? NSHostingView<Left>,
              let rightHost = context.coordinator.rightView as? NSHostingView<Right> else { return }

        // Update content
        leftHost.rootView = left
        rightHost.rootView = right

        let rightIsAttached = splitView.arrangedSubviews.contains(rightHost)

        if showRight && !rightIsAttached {
            // Add the right panel back
            splitView.addArrangedSubview(rightHost)
            splitView.adjustSubviews()

            // Restore saved position or use a reasonable default
            let savedPosition = context.coordinator.lastDividerPosition
            if savedPosition > 380 {
                splitView.setPosition(savedPosition, ofDividerAt: 0)
            } else {
                let totalWidth = splitView.frame.width
                let rightWidth = min(550, totalWidth * 0.5)
                splitView.setPosition(totalWidth - rightWidth, ofDividerAt: 0)
            }
        } else if !showRight && rightIsAttached {
            // Save current divider position before removing
            context.coordinator.lastDividerPosition = leftHost.frame.width

            // Fully remove the right panel — no divider remnant possible
            rightHost.removeFromSuperview()
            splitView.adjustSubviews()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, NSSplitViewDelegate {
        var leftView: NSView?
        var rightView: NSView?  // Strong reference — we remove/re-add this view
        var lastDividerPosition: CGFloat = 0

        func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
            subview === rightView
        }

        func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            380
        }

        func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            splitView.frame.width - 300
        }
    }
}
