//
//  RxMogo+PageCook.swift
//  Pods
//
//  Created by Harly on 2017/9/16.
//
//

import UIKit
import Result
import RxSwift
import RxCocoa
import MGBricks

public typealias PageResponse<Element> = ([Element], MGPage)

internal enum PagableRequestCommand<Element> {
    case refreshAll
    case loadMoreItems
    case responseRecieved(PageResponse<Element>)
}

public struct MGPageRepositoryState<RepositoryElement> : Mutable {

    var shouldLoadNextPage: Bool

    public var repositories: Version<[RepositoryElement]>

    var failure: MGAPIError?

    var pageInfo: MGPage?

    init() {

        shouldLoadNextPage = true
        repositories = Version([])
        failure = nil
    }

}

extension MGPageRepositoryState {

    static func buildNewState() -> MGPageRepositoryState<RepositoryElement> {
        return MGPageRepositoryState()
    }

    static func reduce(state: MGPageRepositoryState, command: PagableRequestCommand<RepositoryElement>) -> MGPageRepositoryState {
        switch command {
        case .refreshAll:
            return MGPageRepositoryState().mutateOne {
                    $0.failure = state.failure
                    $0.pageInfo = MGPage()
            }
        case .responseRecieved(let result):

            return state.mutate {
                $0.repositories = Version($0.repositories.value + result.0)
                $0.shouldLoadNextPage = false
                $0.failure = nil
                $0.pageInfo = result.1
            }

        case .loadMoreItems:
            return state.mutate {
                if $0.failure == nil, let realPage = $0.pageInfo {
                    $0.shouldLoadNextPage = realPage.currentPage < realPage.totalPage
                }
            }
        }
    }
}

public func pagableRepository<Element> (
    allRefresher: Driver<Void>,
    loadNextPageTrigger: @escaping (Driver<MGPageRepositoryState<Element>>) -> Driver<()>,
    performSearch: @escaping (MGPage) -> Observable<PageResponse<Element>>
    ) -> Driver<MGPageRepositoryState<Element>> {

    let searchPerformerFeedback: (Driver<MGPageRepositoryState<Element>>) -> Driver<PagableRequestCommand<Element>> = { state in

        return state.map { (shouldLoadNextPage: $0.shouldLoadNextPage, page: $0.pageInfo) }

            // perform feedback loop effects
            .flatMapLatest { shouldLoadNextPage, page -> Driver<PagableRequestCommand<Element>> in
                if !shouldLoadNextPage {
                    return Driver.empty()
                }

                let finalPage = MGPage()

                if let realPage = page {
                    finalPage.currentPage = realPage.currentPage
                    finalPage.totalPage = realPage.totalPage
                }

                return performSearch(finalPage)
                    .asDriver(onErrorJustReturn: ([], MGPage()))
                    .map(PagableRequestCommand.responseRecieved)
        }
    }

    let inputFeedbackLoop: (Driver<MGPageRepositoryState<Element>>) -> Driver<PagableRequestCommand<Element>> = { state in
        let loadNextPage = loadNextPageTrigger(state).map { _ in PagableRequestCommand<Element>.loadMoreItems }
        let refresher = allRefresher.map { PagableRequestCommand<Element>.refreshAll }

        return Driver.merge(loadNextPage, refresher)
    }

    // Create a system with two feedback loops that drive the system
    // * one that tries to load new pages when necessary
    // * one that sends commands from user input
    return Driver.system(MGPageRepositoryState.buildNewState(),
                         accumulator: MGPageRepositoryState.reduce,
                         feedback: searchPerformerFeedback, inputFeedbackLoop)
}

internal func == (
    lhs: (shouldLoadNextPage: Bool, page: MGPage?),
    rhs: (shouldLoadNextPage: Bool, page: MGPage?)
    ) -> Bool {
    return lhs.shouldLoadNextPage == rhs.shouldLoadNextPage
        && lhs.page?.currentPage == rhs.page?.currentPage
}

//extension DemoRepositoryState {
//    var isOffline: Bool {
//        guard let failure = self.failure else {
//            return false
//        }
//
//        if case .offline = failure {
//            return true
//        }
//        else {
//            return false
//        }
//    }
//
//    var isLimitExceeded: Bool {
//        guard let failure = self.failure else {
//            return false
//        }
//
//        if case .githubLimitReached = failure {
//            return true
//        }
//        else {
//            return false
//        }
//    }
//}
