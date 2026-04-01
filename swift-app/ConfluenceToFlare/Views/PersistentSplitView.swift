import SwiftUI
import AppKit

/// An NSSplitView wrapper that persists divider positions via autosaveName.
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

        let leftHost = NSHostingView(rootView: left)
        let rightHost = NSHostingView(rootView: right)

        splitView.addArrangedSubview(leftHost)
        splitView.addArrangedSubview(rightHost)

        splitView.delegate = context.coordinator

        // Set minimum widths
        leftHost.widthAnchor.constraint(greaterThanOrEqualToConstant: 380).isActive = true
        rightHost.widthAnchor.constraint(greaterThanOrEqualToConstant: 0).isActive = true

        context.coordinator.rightView = rightHost

        if !showRight {
            rightHost.isHidden = true
        }

        return splitView
    }

    func updateNSView(_ splitView: NSSplitView, context: Context) {
        // Update left content
        if let leftHost = splitView.arrangedSubviews.first as? NSHostingView<Left> {
            leftHost.rootView = left
        }

        // Update right content
        if let rightHost = splitView.arrangedSubviews.last as? NSHostingView<Right> {
            rightHost.rootView = right

            if showRight && rightHost.isHidden {
                rightHost.isHidden = false
                splitView.adjustSubviews()

                // If the right panel has zero width, give it a reasonable default
                if rightHost.frame.width < 50 {
                    let totalWidth = splitView.frame.width
                    let rightWidth = min(550, totalWidth * 0.5)
                    splitView.setPosition(totalWidth - rightWidth, ofDividerAt: 0)
                }
            } else if !showRight && !rightHost.isHidden {
                rightHost.isHidden = true
                splitView.adjustSubviews()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, NSSplitViewDelegate {
        weak var rightView: NSView?

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
