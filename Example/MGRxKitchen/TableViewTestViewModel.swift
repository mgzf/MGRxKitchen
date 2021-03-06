//
//  TableViewTestViewModel.swift
//  RxMogo
//
//  Created by Harly on 2017/8/7.
//  Copyright © 2017年 Harly. All rights reserved.
//

import UIKit
import RxCocoa
import RxSwift
import RxSwiftUtilities
import MGRxKitchen
import MGBricks
import Result

internal class MGItem {
    var name: String = ""

    init(str: String) {
        name = str
    }
}

internal class TableViewTestViewModel: HaveRequestRx, PagableRequest {
    var loadingActivity: ActivityIndicator = ActivityIndicator()

    var errorProvider: PublishSubject<RxMGError> = PublishSubject<RxMGError>()

    let disposeBag: DisposeBag = DisposeBag()

    let service: MockService = MockService()

    var serviceDriver: Observable<[Demo]>!

    var firstPage: PublishSubject<Void> = PublishSubject()

    var nextPage: PublishSubject<Void> = PublishSubject()

    var finalPageReached: PublishSubject<Void> = PublishSubject()

    init() {

    }

    func initial() {
        serviceDriver = pagedRequest(request: { page -> Observable<([Demo], MGPage)> in
            return self.pureRequest(withResultSignal: self.service.providePageMock(on: page.currentPage + 1))
        })

    }

    func sectionableData() -> Observable<[MGSection<MGItem>]> {
        let item1 = MGItem(str: "1")
        let item2 = MGItem(str: "2")
        let item3 = MGItem(str: "4")
        let item4 = MGItem(str: "5")

        let section1 = MGSection(header: "header1", items: [item1, item2])
        let section2 = MGSection(header: "header2", items: [item3, item4])

        return Observable.of([section1, section2])

    }

}
