//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import Combine
import StreamChat
import SwiftUI

class PollOptionAllVotesViewModel: ObservableObject, PollVoteListControllerDelegate {
    let option: PollOption
    let controller: PollVoteListController

    @Published var poll: Poll
    @Published var pollVotes = [PollVote]()
    @Published var hasLoadedAllVotes = false
    @Published var errorShown = false

    private var cancellables = Set<AnyCancellable>()
    private(set) var animateChanges = false
    private var loadingVotes = false

    init(poll: Poll, option: PollOption, controller: PollVoteListController? = nil) {
        self.poll = poll
        self.option = option
        let query = PollVoteListQuery(
            pollId: poll.id,
            optionId: option.id,
            pagination: .init(pageSize: 10)
        )
        self.controller = controller ?? InjectedValues[\.chatClient].pollVoteListController(query: query)
        self.controller.delegate = self
        refresh()

        // No animation for initial load
        $pollVotes
            .dropFirst()
            .map { _ in true }
            .assignWeakly(to: \.animateChanges, on: self)
            .store(in: &cancellables)
    }

    func refresh() {
        controller.synchronize { [weak self] error in
            guard let self else { return }
            self.syncState()
            if error != nil {
                self.errorShown = true
            }
            self.loadVotes()
        }
    }

    func onAppear(vote: PollVote) {
        guard let index = pollVotes.firstIndex(where: { $0 == vote }),
              index > pollVotes.count - 10 else {
            return
        }

        loadVotes()
    }

    func controller(
        _ controller: PollVoteListController,
        didChangeVotes changes: [ListChange<PollVote>]
    ) {
        if animateChanges {
            withAnimation {
                syncState()
            }
        } else {
            syncState()
        }
    }

    func controller(_ controller: PollVoteListController, didUpdatePoll poll: Poll) {
        self.poll = poll
    }

    /// Single source of truth: sync published state from the controller.
    private func syncState() {
        pollVotes = Array(controller.votes)
        hasLoadedAllVotes = controller.hasLoadedAllVotes
    }

    private func loadVotes() {
        if loadingVotes || controller.hasLoadedAllVotes {
            return
        }

        loadingVotes = true

        controller.loadMoreVotes { [weak self] error in
            guard let self else { return }
            self.loadingVotes = false
            self.syncState()
            if error != nil {
                self.errorShown = true
            }
        }
    }
}
