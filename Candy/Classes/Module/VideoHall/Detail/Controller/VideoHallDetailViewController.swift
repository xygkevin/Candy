//
//  VideoHallDetailViewController.swift
//  QYNews
//
//  Created by Insect on 2018/12/20.
//  Copyright © 2018 Insect. All rights reserved.
//

import UIKit
import ZFPlayer

class VideoHallDetailViewController: ViewController<VideoHallDetailViewModel> {

    private var albumID: String = ""

    fileprivate var selIndex: Int = 0
    // MARK: - Lazyload
    private lazy var videoView = VideoHallHeaderView.loadFromNib()

    fileprivate lazy var tableView: TableView = {
        let tableView = TableView(frame: CGRect())
        tableView.register(cellType: VideoHallTitleCell.self)
        tableView.register(cellType: VideoHallEpisodeCell.self)
        tableView.register(cellType: VideoHallIntroCell.self)
        tableView.register(cellType: VideoHallRoleCell.self)
        tableView.showsVerticalScrollIndicator = false
        return tableView
    }()

    fileprivate lazy var controlView = ZFPlayerControlView()
    fileprivate lazy var player: ZFPlayerController = {

        let playerManager = ZFAVPlayerManager()
        let player = ZFPlayerController(playerManager: playerManager, containerView: videoView.videoContentView)
        player.controlView = controlView
        return player
    }()

    // MARK: - LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        checkHistory()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        videoView.frame = CGRect(x: 0, y: 0, width: ScreenWidth, height: VideoHallHeaderView.height)
        tableView.frame = CGRect(x: 0, y: videoView.bottom, width: ScreenWidth, height: ScreenHeight - VideoDetailHeader.height)
    }

    // MARK: - init
    init(albumID: String) {
        self.albumID = albumID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    // MARK: - override
    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func makeUI() {
        super.makeUI()

        fd_prefersNavigationBarHidden = true
        view.addSubview(videoView)
        view.addSubview(tableView)
    }

    override func bindViewModel() {
        super.bindViewModel()

        let input = VideoHallDetailViewModel.Input(albumID: albumID)
        let output = viewModel.transform(input: input)

        // 视频真实播放地址
        output.videoPlayInfo
        .filterNil()
        .map { URL(string: $0.video_list.video_1.mainURL) }
        .filterNil()
        .drive(player.rx.assetURL)
        .disposed(by: rx.disposeBag)

        // tableView
        output.items.drive(tableView.rx.items) { [unowned self] tableView, row, item in

            let indexPath = IndexPath(row: row, section: 0)
            switch item {

            case let .title(item):  // 标题

                let cell = tableView.dequeueReusableCell(for: indexPath, cellType: VideoHallTitleCell.self)
                cell.item = item
                return cell
            case let .intro(item): // 简介

                let cell = tableView.dequeueReusableCell(for: indexPath, cellType: VideoHallIntroCell.self)
                cell.item = item
                return cell
            case let .role(item): // 影人

                let cell = tableView.dequeueReusableCell(for: indexPath, cellType: VideoHallRoleCell.self)
                cell.items = item.album.actor_list
                return cell
            case let .episode(item): // 集数

                let cell = tableView.dequeueReusableCell(for: indexPath, cellType: VideoHallEpisodeCell.self)
                cell.items = item.block_list[1].cells
                cell.selIndex = self.selIndex
                return cell
            }
        }
        .disposed(by: rx.disposeBag)

        // 点击了某一集
        let clickEpisode = NotificationCenter.default.rx
        .notification(Notification.clickEpisode)
        .asDriverOnErrorJustComplete()
        .map { $0.object as? Int }
        .filterNil()
        .withLatestFrom(output.episodes) { (index: $0, episodes: $1) }

        // 播放选择的某一集
        clickEpisode
        .map { $0.episodes[$0.index].episode.episode_id }
        .drive(input.episodeID)
        .disposed(by: rx.disposeBag)

        // 保存点击的 index 防止复用
        clickEpisode
        .map { $0.index }
        .drive(rx.selIndex)
        .disposed(by: rx.disposeBag)

        // 保存播放的历史记录
        clickEpisode
        .map { [unowned self] in
            PlayHistory(videoID: self.albumID,
                        episodeID: $0.episodes[$0.index].episode.episode_id,
                        episodeIndex: $0.index,
                        time: 0)
        }
        .drive(historyManager.rx.save)
        .disposed(by: rx.disposeBag)
    }
}

extension VideoHallDetailViewController {

    private func checkHistory() {

        if let history = HistoryManager.getPlayHistory(videoID: albumID) {
            selIndex = history.episodeIndex
        }
    }
}

// MARK: - Reactive
extension Reactive where Base: VideoHallDetailViewController {

    var selIndex: Binder<Int> {
        return Binder(base) { vc, result in
            vc.selIndex = result
            vc.tableView.reloadData()
        }
    }
}
