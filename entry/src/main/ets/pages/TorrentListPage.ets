import { QbittorrentService, TorrentFilter } from '../service/QbittorrentService';
import { TorrentInfo } from '../model/TorrentInfo';
import { TorrentListItem } from '../components/TorrentListItem';
import { AppConstants } from '../common/constants/AppConstants';
import { AppService } from './Index';
import { DemoDataProvider } from '../mock/DemoDataProvider';

@Component
export struct TorrentListPage {
  private service: QbittorrentService = AppService.getService();
  private contentScroller: Scroller = new Scroller();
  @StorageLink('guestMode') guestMode: boolean = false;
  @StorageLink('rootTabBarReserveHeight') rootTabBarReserveHeight: number = 0;
  @StorageLink('downloadTabScrollToTopToken') @Watch('onScrollToTopRequested') downloadTabScrollToTopToken: number = 0;
  @StorageLink('torrentListRefreshToken') @Watch('onRefreshRequested') torrentListRefreshToken: number = 0;
  private readonly filterTabs: string[] = ['全部', '下载中', '已暂停', '已完成'];
  private readonly filterValues: string[] = [
    TorrentFilter.ALL,
    TorrentFilter.DOWNLOADING,
    TorrentFilter.PAUSED,
    TorrentFilter.COMPLETED
  ];
  private readonly sortLabels: string[] = ['按速率', '最近添加', '剩余时间', '按大小'];
  private readonly sortValues: string[] = ['dlspeed', 'added_on', 'eta', 'size'];

  @State torrents: TorrentInfo[] = [];
  @State selectedTab: number = 0;
  @State currentFilter: string = TorrentFilter.ALL;
  @State currentSort: string = 'dlspeed';
  @State searchQuery: string = '';
  @State selectedTagFilter: string = '';
  @State selectedCategoryFilter: string = '';
  @State isLoading: boolean = false;
  @State isRefreshing: boolean = false;
  @State isPullRefreshing: boolean = false;
  @State showFilterPanel: boolean = false;
  @State selectionMode: boolean = false;
  @State selectedHashes: string[] = [];
  @State @Watch('onAnySheetChanged') showBulkActionSheet: boolean = false;
  @State pendingBulkAction: string = '';
  @State actionMessage: string = '';
  @State headerVisible: boolean = true;
  @State categories: string[] = [];
  @State @Watch('onAnySheetChanged') showCategoryMgmtSheet: boolean = false;
  @State newCategoryNameInput: string = '';
  @State isCreatingCategory: boolean = false;
  @State @Watch('onAnySheetChanged') showSetCategorySheet: boolean = false;
  @State isSettingCategory: boolean = false;
  private readonly hideHeaderThreshold: number = 28;
  private readonly showHeaderThreshold: number = 6;
  private hasQueuedRefresh: boolean = false;
  private queuedRefreshFromPull: boolean = false;
  private demoRefreshTick: number = 0;

  aboutToAppear(): void {
    if (this.guestMode) {
      this.loadGuestDemoData();
      this.startAutoRefresh();
      return;
    }
    this.refreshData(false);
    this.refreshCategories();
    this.startAutoRefresh();
  }

  aboutToDisappear(): void {
    this.stopAutoRefresh();
    AppStorage.setOrCreate('showRootTabBar', true);
  }

  private onAnySheetChanged(): void {
    const anyOpen: boolean = this.showBulkActionSheet || this.showCategoryMgmtSheet || this.showSetCategorySheet;
    AppStorage.setOrCreate('showRootTabBar', !anyOpen);
  }

  private onScrollToTopRequested(): void {
    this.headerVisible = true;
    this.contentScroller.scrollEdge(Edge.Top);
  }

  private onRefreshRequested(): void {
    this.refreshData(false);
  }

  private updateHeaderVisibility(): void {
    const offsetY: number = this.contentScroller.currentOffset().yOffset;
    if (this.headerVisible && offsetY > this.hideHeaderThreshold) {
      this.headerVisible = false;
      return;
    }
    if (!this.headerVisible && offsetY < this.showHeaderThreshold) {
      this.headerVisible = true;
    }
  }

  private getHeaderReservedHeight(): number {
    if (this.actionMessage.length > 0) {
      return 166;
    }
    return 118;
  }

  private getFilterPanelHeight(): number {
    // base: outer padding(28) + header row(44) + space(12) + sort row(35) + space(12)
    let h: number = 131;
    if (this.getPanelTagOptions().length > 0) {
      h += 76; // label row(20) + space(8) + chips row(36) + space(12)
    }
    if (this.categories.length > 0) {
      h += 84; // label+管理 row(28) + space(8) + scroll chips row(36) + space(12)
    }
    return h;
  }

  private getTopToolsContainerHeight(): number {
    if (!this.headerVisible) {
      return 0;
    }

    let height: number = 62 + 46 + 44 + 36 + 24 + 12;
    if (this.actionMessage.length > 0) {
      height += 52;
    }
    if (this.showFilterPanel && this.torrents.length > 0) {
      height += this.getFilterPanelHeight();
    }
    if (this.selectionMode && this.torrents.length > 0) {
      height += 72;
    }
    return height;
  }

  private startAutoRefresh(): void {
    this.service.startPolling(AppConstants.DEFAULT_POLLING_INTERVAL, () => {
      this.refreshData(false);
    });
  }

  private stopAutoRefresh(): void {
    this.service.stopPolling();
  }

  private async refreshData(fromPull: boolean): Promise<void> {
    if (this.guestMode) {
      this.loadGuestDemoData();
      this.isLoading = false;
      this.isRefreshing = false;
      this.isPullRefreshing = false;
      return;
    }
    if (this.isRefreshing) {
      if (fromPull) {
        this.isPullRefreshing = false;
      }
      this.hasQueuedRefresh = true;
      this.queuedRefreshFromPull = this.queuedRefreshFromPull || fromPull;
      if (fromPull) {
        this.isPullRefreshing = true;
      }
      return;
    }

    this.isRefreshing = true;
    if (fromPull) {
      this.isPullRefreshing = true;
    } else if (this.torrents.length === 0) {
      this.isLoading = true;
    }

    try {
      const filter: string = this.currentFilter === TorrentFilter.ALL ? '' : this.currentFilter;
      const nextTorrents: TorrentInfo[] = await this.service.fetchTorrentList(filter, this.currentSort);
      this.torrents = nextTorrents;
      this.trimSelection();
    } finally {
      const shouldRefreshAgain: boolean = this.hasQueuedRefresh;
      const nextRefreshFromPull: boolean = this.queuedRefreshFromPull;
      this.hasQueuedRefresh = false;
      this.queuedRefreshFromPull = false;
      this.isLoading = false;
      if (shouldRefreshAgain) {
        this.isRefreshing = false;
        if (!nextRefreshFromPull) {
          this.isPullRefreshing = false;
        }
        this.refreshData(nextRefreshFromPull);
        return;
      }
      this.isRefreshing = false;
      this.isPullRefreshing = false;
    }
  }

  private async changeFilter(index: number): Promise<void> {
    this.selectedTab = index;
    this.currentFilter = this.filterValues[index];
    this.clearSelectionState();
    this.headerVisible = true;
    this.contentScroller.scrollEdge(Edge.Top);
    await this.refreshData(false);
  }

  private async changeSort(index: number): Promise<void> {
    this.currentSort = this.sortValues[index];
    this.headerVisible = true;
    this.contentScroller.scrollEdge(Edge.Top);
    await this.refreshData(false);
  }

  private trimSelection(): void {
    const next: string[] = [];
    let i: number = 0;
    while (i < this.selectedHashes.length) {
      if (this.findTorrent(this.selectedHashes[i]) !== null) {
        next.push(this.selectedHashes[i]);
      }
      i += 1;
    }
    this.selectedHashes = next;
    if (this.selectedHashes.length === 0) {
      this.showBulkActionSheet = false;
    }
  }

  private findTorrent(hash: string): TorrentInfo | null {
    let i: number = 0;
    while (i < this.torrents.length) {
      if (this.torrents[i].hash === hash) {
        return this.torrents[i];
      }
      i += 1;
    }
    return null;
  }

  private getVisibleTorrents(): TorrentInfo[] {
    const visible: TorrentInfo[] = [];
    const keyword: string = this.searchQuery.trim().toLowerCase();

    let i: number = 0;
    while (i < this.torrents.length) {
      const torrent: TorrentInfo = this.torrents[i];

      if (keyword.length > 0 && !this.matchesKeyword(torrent, keyword)) {
        i += 1;
        continue;
      }
      if (this.selectedTagFilter.length > 0 && !torrent.tags.includes(this.selectedTagFilter)) {
        i += 1;
        continue;
      }
      if (this.selectedCategoryFilter.length > 0 && torrent.category !== this.selectedCategoryFilter) {
        i += 1;
        continue;
      }

      visible.push(torrent);
      i += 1;
    }
    visible.sort((a: TorrentInfo, b: TorrentInfo) => this.compareVisibleTorrents(a, b));
    return visible;
  }

  private compareVisibleTorrents(a: TorrentInfo, b: TorrentInfo): number {
    if (this.currentFilter === TorrentFilter.ALL) {
      const rankDiff: number = this.getTorrentDisplayRank(a) - this.getTorrentDisplayRank(b);
      if (rankDiff !== 0) {
        return rankDiff;
      }
    }

    if (this.currentSort === 'added_on') {
      return b.added_on - a.added_on;
    }
    if (this.currentSort === 'eta') {
      const aEta: number = a.eta > 0 ? a.eta : Number.MAX_SAFE_INTEGER;
      const bEta: number = b.eta > 0 ? b.eta : Number.MAX_SAFE_INTEGER;
      if (aEta !== bEta) {
        return aEta - bEta;
      }
      return b.added_on - a.added_on;
    }
    if (this.currentSort === 'size') {
      if (a.size !== b.size) {
        return b.size - a.size;
      }
      return b.added_on - a.added_on;
    }

    if (a.dlspeed !== b.dlspeed) {
      return b.dlspeed - a.dlspeed;
    }
    if (a.upspeed !== b.upspeed) {
      return b.upspeed - a.upspeed;
    }
    return b.added_on - a.added_on;
  }

  private getTorrentDisplayRank(torrent: TorrentInfo): number {
    if (torrent.isDownloading()) {
      return 0;
    }
    if (!torrent.isPaused() && !torrent.isCompleted()) {
      return 1;
    }
    if (torrent.isPaused()) {
      return 2;
    }
    return 3;
  }

  private matchesKeyword(torrent: TorrentInfo, keyword: string): boolean {
    const name: string = torrent.name.toLowerCase();
    const tags: string = torrent.tags.toLowerCase();
    const category: string = torrent.category.toLowerCase();
    return name.includes(keyword) || tags.includes(keyword) || category.includes(keyword);
  }

  private getSelectedCount(): number {
    return this.selectedHashes.length;
  }

  private isSelected(hash: string): boolean {
    return this.selectedHashes.indexOf(hash) >= 0;
  }

  private toggleSelection(hash: string): void {
    const next: string[] = [];
    let found: boolean = false;
    let i: number = 0;
    while (i < this.selectedHashes.length) {
      if (this.selectedHashes[i] === hash) {
        found = true;
      } else {
        next.push(this.selectedHashes[i]);
      }
      i += 1;
    }
    if (!found) {
      next.push(hash);
    }
    this.selectedHashes = next;
  }

  private toggleSelectionMode(): void {
    if (this.torrents.length === 0) {
      AppService.pushPage('AddTorrent');
      return;
    }

    this.selectionMode = !this.selectionMode;
    if (!this.selectionMode) {
      this.selectedHashes = [];
      this.showBulkActionSheet = false;
      this.pendingBulkAction = '';
    }
  }

  private clearSelectionState(): void {
    this.selectedHashes = [];
    this.selectionMode = false;
    this.showBulkActionSheet = false;
    this.pendingBulkAction = '';
  }

  private toggleFilterPanel(): void {
    this.showFilterPanel = !this.showFilterPanel;
    this.headerVisible = true;
    if (this.showFilterPanel) {
      this.contentScroller.scrollEdge(Edge.Top);
      this.refreshCategories();
    }
  }

  private async refreshCategories(): Promise<void> {
    if (this.guestMode) {
      return;
    }
    this.categories = await this.service.fetchCategories();
  }

  private async handleCreateCategory(): Promise<void> {
    const name: string = this.newCategoryNameInput.trim();
    if (name.length === 0 || this.isCreatingCategory) {
      return;
    }
    this.isCreatingCategory = true;
    const success: boolean = await this.service.createCategory(name, '');
    this.isCreatingCategory = false;
    if (success) {
      this.newCategoryNameInput = '';
      await this.refreshCategories();
    } else {
      this.actionMessage = '创建分类失败';
    }
  }

  private async handleDeleteCategory(name: string): Promise<void> {
    const success: boolean = await this.service.removeCategories([name]);
    if (success) {
      if (this.selectedCategoryFilter === name) {
        this.selectedCategoryFilter = '';
      }
      await this.refreshCategories();
    } else {
      this.actionMessage = '删除分类失败';
    }
  }

  private async handleSetCategory(category: string): Promise<void> {
    if (this.isSettingCategory || this.selectedHashes.length === 0) {
      return;
    }
    this.isSettingCategory = true;
    const success: boolean = await this.service.setTorrentCategory(this.selectedHashes, category);
    this.isSettingCategory = false;
    this.showSetCategorySheet = false;
    if (success) {
      this.actionMessage = category.length > 0 ? `已设置分类"${category}"` : '已清除分类';
      this.selectedHashes = [];
      this.selectionMode = false;
      await this.refreshData(false);
    } else {
      this.actionMessage = '设置分类失败';
    }
  }

  private toggleSelectAll(): void {
    const visible: TorrentInfo[] = this.getVisibleTorrents();
    if (visible.length === 0) {
      return;
    }
    if (this.selectedHashes.length === visible.length) {
      this.selectedHashes = [];
      return;
    }

    const next: string[] = [];
    let i: number = 0;
    while (i < visible.length) {
      next.push(visible[i].hash);
      i += 1;
    }
    this.selectedHashes = next;
  }

  private requestBulkAction(action: string): void {
    if (this.selectedHashes.length === 0) {
      this.actionMessage = '先选择至少 1 个任务';
      return;
    }
    if (this.guestMode) {
      this.actionMessage = '演示模式暂不支持批量操作';
      return;
    }
    if (action === 'setCategory') {
      this.showSetCategorySheet = true;
      return;
    }
    this.pendingBulkAction = action;
    this.showBulkActionSheet = true;
  }

  private cancelBulkAction(): void {
    this.showBulkActionSheet = false;
    this.pendingBulkAction = '';
  }

  private async confirmBulkAction(): Promise<void> {
    if (this.selectedHashes.length === 0) {
      this.cancelBulkAction();
      return;
    }

    let success: boolean = false;
    if (this.pendingBulkAction === 'delete') {
      success = await this.service.deleteTorrents(this.selectedHashes, false);
      this.actionMessage = success ? `已删除 ${this.selectedHashes.length} 个任务` : '批量删除失败';
    } else if (this.pendingBulkAction === 'resume') {
      success = await this.service.resumeTorrents(this.selectedHashes);
      this.actionMessage = success ? `已恢复 ${this.selectedHashes.length} 个任务` : '批量恢复失败';
    } else {
      success = await this.service.pauseTorrents(this.selectedHashes);
      this.actionMessage = success ? `已暂停 ${this.selectedHashes.length} 个任务` : '批量暂停失败';
    }

    this.cancelBulkAction();
    if (success) {
      this.selectedHashes = [];
      this.selectionMode = false;
      await this.refreshData(false);
    }
  }

  private getBulkActionLabel(): string {
    if (this.pendingBulkAction === 'delete') {
      return '删除';
    }
    if (this.pendingBulkAction === 'resume') {
      return '恢复';
    }
    return '暂停';
  }

  private getBulkConfirmButtonText(): string {
    if (this.pendingBulkAction === 'delete') {
      return '确认删除';
    }
    if (this.pendingBulkAction === 'resume') {
      return '确认恢复';
    }
    return '确认暂停';
  }

  private getModeBadgeText(): string {
    if (this.showBulkActionSheet) {
      return '批量结果';
    }
    if (this.showFilterPanel) {
      return '筛选展开';
    }
    if (this.selectionMode) {
      return '批量模式';
    }
    if (this.torrents.length === 0) {
      return '自动待机';
    }
    return '队列视图';
  }

  private getLeftBadgeText(): string {
    if (this.torrents.length === 0 && !this.isLoading) {
      return '暂无任务';
    }
    return '实时队列';
  }

  private getCurrentSortLabel(): string {
    if (this.showFilterPanel || this.selectedTagFilter.length > 0 || this.selectedCategoryFilter.length > 0) {
      return '筛选';
    }
    let i: number = 0;
    while (i < this.sortValues.length) {
      if (this.sortValues[i] === this.currentSort) {
        return '筛选';
      }
      i += 1;
    }
    return '筛选';
  }

  private isFilterActive(): boolean {
    return this.showFilterPanel || this.selectedTagFilter.length > 0 || this.selectedCategoryFilter.length > 0;
  }

  private shouldResumeSelection(): boolean {
    if (this.selectedHashes.length === 0) {
      return false;
    }

    let i: number = 0;
    while (i < this.selectedHashes.length) {
      const torrent: TorrentInfo | null = this.findTorrent(this.selectedHashes[i]);
      if (torrent === null || !torrent.isPaused()) {
        return false;
      }
      i += 1;
    }
    return true;
  }

  private getPanelTagOptions(): string[] {
    const values: string[] = [];
    let i: number = 0;
    while (i < this.torrents.length) {
      const tagLine: string = this.torrents[i].tags;
      if (tagLine.length > 0) {
        const tags: string[] = tagLine.split(',');
        let j: number = 0;
        while (j < tags.length) {
          const tag: string = tags[j].trim();
          if (tag.length > 0 && values.indexOf(tag) < 0) {
            values.push(tag);
            if (values.length >= 2) {
              return values;
            }
          }
          j += 1;
        }
      }
      i += 1;
    }
    return values;
  }

  private getPanelCategoryOptions(): string[] {
    const values: string[] = [];
    let i: number = 0;
    while (i < this.torrents.length) {
      const category: string = this.torrents[i].category.trim();
      if (category.length > 0 && values.indexOf(category) < 0) {
        values.push(category);
        if (values.length >= 2) {
          return values;
        }
      }
      i += 1;
    }
    return values;
  }

  private getAffectedNames(): string[] {
    const names: string[] = [];
    let i: number = 0;
    while (i < this.selectedHashes.length && names.length < 3) {
      const torrent: TorrentInfo | null = this.findTorrent(this.selectedHashes[i]);
      if (torrent !== null) {
        names.push(torrent.name);
      }
      i += 1;
    }
    return names;
  }

  private getTorrentRenderKey(torrent: TorrentInfo): string {
    return torrent.hash;
  }

  private openTorrent(hash: string): void {
    if (this.guestMode) {
      this.actionMessage = '演示模式暂不支持查看详情';
      return;
    }
    AppService.pushPage('TorrentDetail', hash);
  }

  private loadGuestDemoData(): void {
    this.torrents = DemoDataProvider.createTorrents(this.demoRefreshTick);
    this.trimSelection();
    this.demoRefreshTick += 1;
  }

  build() {
    Stack() {
      this.pageBackgroundLayer()

      Column({ space: 0 }) {
        Column() {
          Column({ space: 12 }) {
            this.headerSection()

            if (this.actionMessage.length > 0) {
              this.actionBanner()
            }

            this.toolbarSection()
            this.segmentSection()

            if (this.showFilterPanel && this.torrents.length > 0) {
              this.filterPanelSection()
            }

            if (this.selectionMode && this.torrents.length > 0) {
              this.bulkBarSection()
            }
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 62, bottom: 12 })
        }
        .width('100%')
        .height(this.getTopToolsContainerHeight())
        .opacity(this.headerVisible ? 1 : 0)
        .clip(true)
        .animation({
          duration: 220,
          curve: Curve.Friction
        })

        Refresh({ refreshing: $$this.isPullRefreshing }) {
          Scroll(this.contentScroller) {
            Column({ space: 12 }) {
              this.listSection()

              Blank()
                .height(this.rootTabBarReserveHeight)
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 0, bottom: 0 })
          }
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .onDidScroll((_xOffset: number, _yOffset: number) => {
            this.updateHeaderVisibility();
          })
          .width('100%')
          .layoutWeight(1)
          .backgroundColor(Color.Transparent)
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor(Color.Transparent)
        .onRefreshing(() => {
          this.refreshData(true);
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .blur(this.showBulkActionSheet || this.showCategoryMgmtSheet || this.showSetCategorySheet ? 16 : 0)
      .animation({ duration: 220, curve: Curve.EaseOut })

      Column() {
        Blank()
        if (!this.headerVisible && this.torrents.length > 0 &&
            !this.showBulkActionSheet && !this.showCategoryMgmtSheet && !this.showSetCategorySheet) {
          Stack({ alignContent: Alignment.Center }) {
            SymbolGlyph($r('sys.symbol.chevron_up'))
              .fontSize(18)
              .fontColor([$r('app.color.tab_active_fg')])
          }
          .width(44)
          .height(44)
          .backgroundColor($r('app.color.accent_color'))
          .borderRadius(999)
          .shadow({ radius: 20, color: '#2563EB40', offsetX: 0, offsetY: 6 })
          .margin({ right: 20, bottom: this.rootTabBarReserveHeight + 16 })
          .transition(
            TransitionEffect.asymmetric(
              TransitionEffect.opacity(0)
                .combine(TransitionEffect.scale({ x: 0.75, y: 0.75 }))
                .animation({ duration: 260, curve: Curve.FastOutSlowIn }),
              TransitionEffect.opacity(0)
                .combine(TransitionEffect.scale({ x: 0.75, y: 0.75 }))
                .animation({ duration: 180, curve: Curve.EaseIn })
            )
          )
          .onClick(() => {
            this.onScrollToTopRequested();
          })
        }
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.End)
      .justifyContent(FlexAlign.End)
      .hitTestBehavior(HitTestMode.Transparent)

      if (this.showBulkActionSheet) {
        this.bulkActionSheet()
      }
      if (this.showCategoryMgmtSheet) {
        this.categoryMgmtSheet()
      }
      if (this.showSetCategorySheet) {
        this.setCategorySheet()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  pageBackgroundLayer() {
    Stack() {
      Row()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [
            [$r('app.color.page_gradient_top'), 0],
            [$r('app.color.page_gradient_mid'), 0.38],
            [$r('app.color.page_background'), 1]
          ]
        })

      Row()
        .width('118%')
        .height(180)
        .linearGradient({
          angle: 90,
          colors: [[Color.Transparent, 0], [$r('app.color.dashboard_surface_info'), 0.36], [$r('app.color.dashboard_surface_success'), 0.76], [Color.Transparent, 1]]
        })
        .borderRadius(56)
        .position({ x: -34, y: 118 })

      Row()
        .width('112%')
        .height(120)
        .linearGradient({
          angle: 90,
          colors: [[Color.Transparent, 0], [$r('app.color.dashboard_surface_success'), 0.48], [$r('app.color.dashboard_surface_warning'), 0.88], [Color.Transparent, 1]]
        })
        .borderRadius(48)
        .position({ x: -26, y: 276 })

      Row()
        .width('100%')
        .height(160)
        .linearGradient({
          angle: 180,
          colors: [[Color.Transparent, 0], [$r('app.color.page_background'), 1]]
        })
        .position({ x: 0, y: 560 })

      Column() {
        Row()
          .width('100%')
          .height(760)
          .linearGradient({
            angle: 180,
            colors: [[Color.Transparent, 0], [Color.Transparent, 0.55], [$r('app.color.page_background'), 1]]
          })
        Blank()
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  actionBanner() {
    Row() {
      Text(this.actionMessage)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Blank()
      Text('关闭')
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.accent_color'))
        .onClick(() => {
          this.actionMessage = '';
        })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.glass_bg_card'))
    .backdropBlur(20)
    .border({
      width: 1,
      color: $r('app.color.glass_border')
    })
    .borderRadius(16)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  headerSection() {
    Row() {
      Text('下载管理')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(-0.5)
        .fontColor($r('app.color.text_primary'))
    }
    .width('100%')
    .height(46)
    .opacity(this.headerVisible ? 1 : 0)
    .translate({ x: 0, y: this.headerVisible ? 0 : -14 })
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Start)
    .animation({
      duration: 260,
      curve: Curve.Friction
    })
  }

  @Builder
  segmentSection() {
    Row({ space: 8 }) {
      ForEach(this.filterTabs, (tab: string, index?: number) => {
        if (index !== undefined) {
          Row({ space: 4 }) {
            if (index === 0) {
              SymbolGlyph($r('sys.symbol.list_bullet'))
                .fontSize(13)
                .fontColor([this.selectedTab === index ? $r('app.color.tab_active_fg') : $r('app.color.tab_inactive_fg')])
            } else if (index === 1) {
              SymbolGlyph($r('sys.symbol.arrow_down_circle'))
                .fontSize(13)
                .fontColor([this.selectedTab === index ? $r('app.color.tab_active_fg') : $r('app.color.tab_inactive_fg')])
            } else if (index === 2) {
              SymbolGlyph($r('sys.symbol.pause_circle'))
                .fontSize(13)
                .fontColor([this.selectedTab === index ? $r('app.color.tab_active_fg') : $r('app.color.tab_inactive_fg')])
            } else {
              SymbolGlyph($r('sys.symbol.checkmark_circle'))
                .fontSize(13)
                .fontColor([this.selectedTab === index ? $r('app.color.tab_active_fg') : $r('app.color.tab_inactive_fg')])
            }
            Text(tab)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.selectedTab === index ? $r('app.color.tab_active_fg') : $r('app.color.tab_inactive_fg'))
          }
          .layoutWeight(1)
          .height(36)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .backgroundColor(this.selectedTab === index ? $r('app.color.tab_active_bg') : $r('app.color.glass_bg_card'))
          .backdropBlur(this.selectedTab === index ? 0 : 20)
          .border({
            width: this.selectedTab === index ? 0 : 1,
            color: $r('app.color.glass_border')
          })
          .borderRadius(999)
          .onClick(() => {
            this.changeFilter(index);
          })
        }
      }, (tab: string, index?: number) => `${index}`)
    }
    .width('100%')
  }

  @Builder
  toolbarSection() {
    Row({ space: 8 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(17)
          .fontColor([$r('app.color.tab_inactive_fg')])
        TextInput({ placeholder: '搜索任务、标签或分类', text: this.searchQuery })
          .placeholderFont({ size: 14, weight: FontWeight.Normal })
          .placeholderColor($r('app.color.tab_inactive_fg'))
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor(Color.Transparent)
          .layoutWeight(1)
          .onChange((value: string) => {
            this.searchQuery = value;
            this.clearSelectionState();
            this.headerVisible = true;
            this.contentScroller.scrollEdge(Edge.Top);
          })
        if (this.searchQuery.length > 0) {
          Row() {
            Text('×')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_secondary'))
          }
          .width(20)
          .height(20)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .backgroundColor($r('app.color.dashboard_surface_muted'))
          .borderRadius(999)
          .onClick(() => {
            this.searchQuery = '';
            this.clearSelectionState();
            this.headerVisible = true;
            this.contentScroller.scrollEdge(Edge.Top);
          })
        }
      }
      .layoutWeight(1)
      .height(44)
      .padding({ left: 14, right: 14 })
      .backgroundColor($r('app.color.glass_bg_card'))
      .backdropBlur(20)
      .border({
        width: 1,
        color: $r('app.color.glass_border')
      })
      .borderRadius(999)

      Row({ space: 5 }) {
        SymbolGlyph($r('sys.symbol.slider_horizontal_2'))
          .fontSize(15)
          .fontColor([this.isFilterActive() ? $r('app.color.accent_color') : $r('app.color.text_primary')])
        Text(this.getCurrentSortLabel())
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isFilterActive() ? $r('app.color.accent_color') : $r('app.color.text_primary'))
      }
      .height(44)
      .padding({ left: 12, right: 12 })
      .backgroundColor(this.isFilterActive() ? $r('app.color.dashboard_surface_info') : $r('app.color.glass_bg_card'))
      .backdropBlur(20)
      .border({
        width: 1,
        color: this.isFilterActive() ? $r('app.color.download_selected_border') : $r('app.color.glass_border')
      })
      .borderRadius(999)
      .onClick(() => {
        this.toggleFilterPanel();
      })

      Row({ space: 5 }) {
        SymbolGlyph(this.torrents.length === 0 ? $r('sys.symbol.plus') :
          (this.selectionMode ? $r('sys.symbol.xmark') : $r('sys.symbol.checkmark_circle')))
          .fontSize(this.torrents.length === 0 ? 15 : 14)
          .fontColor([$r('app.color.accent_color')])
        Text(this.torrents.length === 0 ? '添加' : (this.selectionMode ? '取消' : '多选'))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.accent_color'))
      }
      .height(44)
      .padding({ left: 12, right: 12 })
      .backgroundColor(this.selectionMode ? $r('app.color.glass_bg_card') : $r('app.color.dashboard_surface_info'))
      .backdropBlur(20)
      .border({
        width: 1,
        color: this.selectionMode ? $r('app.color.glass_border') : $r('app.color.download_selected_border')
      })
      .borderRadius(999)
      .onClick(() => {
        this.toggleSelectionMode();
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  filterPanelSection() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 4 }) {
          Text('筛选与排序')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('聚焦活跃下载，按速率优先查看')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text(`结果 ${this.getVisibleTorrents().length} 项`)
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.accent_color'))
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor($r('app.color.dashboard_surface_info'))
          .borderRadius(999)
      }
      .width('100%')

      Row({ space: 8 }) {
        ForEach(this.sortLabels, (label: string, index?: number) => {
          if (index !== undefined) {
            Row() {
              Text(label)
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.currentSort === this.sortValues[index] ? $r('app.color.tab_active_fg') : $r('app.color.text_primary'))
            }
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor(this.currentSort === this.sortValues[index] ? $r('app.color.tab_active_bg') : $r('app.color.dashboard_surface_soft'))
            .border({
              width: this.currentSort === this.sortValues[index] ? 0 : 1,
              color: $r('app.color.dashboard_border')
            })
            .borderRadius(999)
            .onClick(() => {
              this.changeSort(index);
            })
          }
        }, (label: string, index?: number) => `${index}`)
      }
      .width('100%')

      if (this.getPanelTagOptions().length > 0 || this.categories.length > 0) {
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            Text('标签')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_secondary'))
            Text(this.selectedTagFilter.length > 0 ? this.selectedTagFilter : '全部')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.accent_color'))
          }

          Row({ space: 8 }) {
            Row() {
              Text('全部标签')
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.selectedTagFilter.length === 0 ? $r('app.color.accent_color') : $r('app.color.text_primary'))
            }
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor(this.selectedTagFilter.length === 0 ? $r('app.color.dashboard_surface_info') : $r('app.color.dashboard_surface_soft'))
            .border({
              width: 1,
              color: this.selectedTagFilter.length === 0 ? $r('app.color.download_selected_border') : $r('app.color.dashboard_border')
            })
            .borderRadius(999)
            .onClick(() => {
              this.selectedTagFilter = '';
              this.clearSelectionState();
            })

            ForEach(this.getPanelTagOptions(), (tag: string) => {
              Row() {
                Text(`标签: ${tag}`)
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.selectedTagFilter === tag ? $r('app.color.accent_color') : $r('app.color.text_primary'))
              }
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .backgroundColor(this.selectedTagFilter === tag ? $r('app.color.dashboard_surface_info') : $r('app.color.dashboard_surface_soft'))
              .border({
                width: 1,
                color: this.selectedTagFilter === tag ? $r('app.color.download_selected_border') : $r('app.color.dashboard_border')
              })
              .borderRadius(999)
              .onClick(() => {
                this.selectedTagFilter = this.selectedTagFilter === tag ? '' : tag;
                this.clearSelectionState();
              })
            }, (tag: string) => tag)
          }
          .width('100%')
        }
      }

      if (this.categories.length > 0) {
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            Text('分类')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_secondary'))
            Text(this.selectedCategoryFilter.length > 0 ? this.selectedCategoryFilter : '全部')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.accent_color'))
            Blank()
            Text('管理')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.accent_color'))
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .backgroundColor($r('app.color.dashboard_surface_info'))
              .borderRadius(999)
              .onClick(() => {
                this.showCategoryMgmtSheet = true;
              })
          }
          .width('100%')

          Scroll() {
            Row({ space: 8 }) {
              Row() {
                Text('全部分类')
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.selectedCategoryFilter.length === 0 ? $r('app.color.accent_color') : $r('app.color.text_primary'))
              }
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .backgroundColor(this.selectedCategoryFilter.length === 0 ? $r('app.color.dashboard_surface_info') : $r('app.color.dashboard_surface_soft'))
              .border({
                width: 1,
                color: this.selectedCategoryFilter.length === 0 ? $r('app.color.download_selected_border') : $r('app.color.dashboard_border')
              })
              .borderRadius(999)
              .onClick(() => {
                this.selectedCategoryFilter = '';
                this.clearSelectionState();
              })

              ForEach(this.categories, (category: string) => {
                Row() {
                  Text(category)
                    .fontSize(11)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.selectedCategoryFilter === category ? $r('app.color.accent_color') : $r('app.color.text_primary'))
                }
                .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                .backgroundColor(this.selectedCategoryFilter === category ? $r('app.color.dashboard_surface_info') : $r('app.color.dashboard_surface_soft'))
                .border({
                  width: 1,
                  color: this.selectedCategoryFilter === category ? $r('app.color.download_selected_border') : $r('app.color.dashboard_border')
                })
                .borderRadius(999)
                .onClick(() => {
                  this.selectedCategoryFilter = this.selectedCategoryFilter === category ? '' : category;
                  this.clearSelectionState();
                })
              }, (category: string) => category)
            }
            .constraintSize({ minWidth: '100%' })
          }
          .scrollBar(BarState.Off)
          .scrollable(ScrollDirection.Horizontal)
          .width('100%')
        }
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.card_background'))
    .border({
      width: 1,
      color: $r('app.color.dashboard_border')
    })
    .borderRadius(24)
  }

  @Builder
  bulkBarSection() {
    Scroll() {
      Row({ space: 8 }) {
        Row({ space: 8 }) {
          Circle()
            .width(8)
            .height(8)
            .fill($r('app.color.accent_color'))
          Text(`已选 ${this.getSelectedCount()} 项`)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.accent_color'))
        }
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor($r('app.color.dashboard_surface_info'))
        .borderRadius(999)

        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.checkmark_circle'))
            .fontSize(14)
            .fontColor([$r('app.color.text_primary')])
          Text('全选')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
        }
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor($r('app.color.dashboard_surface_soft'))
        .border({
          width: 1,
          color: $r('app.color.dashboard_border')
        })
        .borderRadius(999)
        .onClick(() => {
          this.toggleSelectAll();
        })

        Row({ space: 6 }) {
          SymbolGlyph(this.shouldResumeSelection() ? $r('sys.symbol.play_fill') : $r('sys.symbol.pause_fill'))
            .fontSize(13)
            .fontColor([$r('app.color.text_primary')])
          Text(this.shouldResumeSelection() ? '继续' : '暂停')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
        }
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor($r('app.color.dashboard_surface_soft'))
        .border({
          width: 1,
          color: $r('app.color.dashboard_border')
        })
        .borderRadius(999)
        .onClick(() => {
          this.requestBulkAction(this.shouldResumeSelection() ? 'resume' : 'pause');
        })

        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.folder'))
            .fontSize(14)
            .fontColor([$r('app.color.text_primary')])
          Text('分类')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
        }
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor($r('app.color.dashboard_surface_soft'))
        .border({
          width: 1,
          color: $r('app.color.dashboard_border')
        })
        .borderRadius(999)
        .onClick(() => {
          this.requestBulkAction('setCategory');
        })

        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.trash'))
            .fontSize(14)
            .fontColor([$r('app.color.error_color')])
          Text('删除')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.error_color'))
        }
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor($r('app.color.dashboard_surface_danger'))
        .border({
          width: 1,
          color: $r('app.color.download_warn_border')
        })
        .borderRadius(999)
        .onClick(() => {
          this.requestBulkAction('delete');
        })
      }
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .constraintSize({ minWidth: '100%' })
      .alignItems(VerticalAlign.Center)
    }
    .scrollBar(BarState.Off)
    .scrollable(ScrollDirection.Horizontal)
    .width('100%')
    .backgroundColor($r('app.color.glass_bg_card'))
    .backdropBlur(20)
    .border({
      width: 1,
      color: $r('app.color.glass_border')
    })
    .borderRadius(20)
  }

  @Builder
  listSection() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 4 }) {
          Text(this.showFilterPanel ? '筛选结果' : (this.torrents.length === 0 ? '空下载队列' : '下载队列'))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text(this.getListSubtitle())
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text(this.getListBadgeText())
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.accent_color'))
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor($r('app.color.glass_bg_chip'))
          .border({
            width: 1,
            color: $r('app.color.glass_border')
          })
          .borderRadius(999)
      }
      .width('100%')

      if (this.guestMode && this.torrents.length === 0 && !this.isLoading) {
        this.guestEmptySection()
      } else if (this.torrents.length === 0 && !this.isLoading) {
        this.emptyQueueSection()
      } else if (this.getVisibleTorrents().length === 0 && !this.isLoading) {
        this.emptyResultSection()
      } else if (this.isLoading && this.torrents.length === 0) {
        this.loadingQueueSection()
      } else {
        Column({ space: 10 }) {
          ForEach(this.getVisibleTorrents(), (torrent: TorrentInfo) => {
            TorrentListItem({
              torrent: torrent,
              selectionMode: this.selectionMode,
              isSelected: this.isSelected(torrent.hash),
              onItemClick: (hash: string) => {
                this.openTorrent(hash);
              },
              onToggleSelect: (hash: string) => {
                this.toggleSelection(hash);
              }
            })
            .transition(
              TransitionEffect.asymmetric(
                TransitionEffect.opacity(0)
                  .combine(TransitionEffect.translate({ y: 20 }))
                  .animation({ duration: 350, curve: Curve.FastOutSlowIn }),
                TransitionEffect.opacity(0)
                  .combine(TransitionEffect.translate({ y: -8 }))
                  .animation({ duration: 200, curve: Curve.EaseIn })
              )
            )
          }, (torrent: TorrentInfo) => this.getTorrentRenderKey(torrent))
        }
        .width('100%')
        .transition(
          TransitionEffect.opacity(0)
            .combine(TransitionEffect.translate({ y: 12 }))
            .animation({ duration: 320, curve: Curve.FastOutSlowIn })
        )
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.card_background'))
    .border({
      width: 1,
      color: $r('app.color.dashboard_border')
    })
    .borderRadius(24)
    .shadow({
      radius: 18,
      color: '#0F172A12',
      offsetX: 0,
      offsetY: 8
    })
  }

  @Builder
  loadingQueueSection() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        LoadingProgress()
          .width(18)
          .height(18)
          .color($r('app.color.accent_color'))
        Text('正在同步下载队列')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      this.loadingCard()
      this.loadingCard()
    }
    .width('100%')
  }

  @Builder
  loadingCard() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Column({ space: 6 }) {
          Row()
            .width('78%')
            .height(14)
            .backgroundColor($r('app.color.dashboard_border_soft'))
            .borderRadius(999)
          Row()
            .width('56%')
            .height(12)
            .backgroundColor($r('app.color.dashboard_surface_muted'))
            .borderRadius(999)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Row()
          .width(54)
          .height(24)
          .backgroundColor($r('app.color.dashboard_surface_info'))
          .borderRadius(999)
      }
      .width('100%')

      Row()
        .width('100%')
        .height(6)
        .backgroundColor($r('app.color.dashboard_progress_track'))
        .borderRadius(999)

      Row({ space: 8 }) {
        Row()
          .width(42)
          .height(22)
          .backgroundColor($r('app.color.dashboard_surface_info'))
          .borderRadius(999)
        Row()
          .width(70)
          .height(12)
          .backgroundColor($r('app.color.dashboard_surface_muted'))
          .borderRadius(999)
        Row()
          .width(64)
          .height(12)
          .backgroundColor($r('app.color.dashboard_surface_muted'))
          .borderRadius(999)
        Blank()
        Row()
          .width(48)
          .height(12)
          .backgroundColor($r('app.color.dashboard_surface_muted'))
          .borderRadius(999)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.glass_bg_chip'))
    .border({
      width: 1,
      color: $r('app.color.glass_border')
    })
    .borderRadius(20)
  }

  @Builder
  emptyQueueSection() {
    Column({ space: 14 }) {
      Stack() {
        Circle()
          .width(60)
          .height(60)
          .fill($r('app.color.dashboard_surface_info'))
          .margin({ top: 10 })

        Column({ space: 6 }) {
          Row()
            .width(76)
            .height(42)
            .backgroundColor($r('app.color.card_background'))
            .border({
              width: 1,
              color: $r('app.color.download_selected_border')
            })
            .borderRadius(16)

          Circle()
            .width(18)
            .height(18)
            .fill($r('app.color.accent_color'))
            .margin({ left: 56, top: -44 })
        }
      }
      .width(112)
      .height(96)

      Column({ space: 6 }) {
        Text('还没有下载任务')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('添加种子或磁力链接后，队列和批量操作会出现在这里。')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
      }
      .alignItems(HorizontalAlign.Center)

      Row({ space: 10 }) {
        Button('添加下载任务')
          .layoutWeight(1)
          .height(46)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.tab_active_fg'))
          .backgroundColor($r('app.color.accent_color'))
          .borderRadius(999)
          .onClick(() => {
            AppService.pushPage('AddTorrent');
          })

        Button('查看使用说明')
          .layoutWeight(1)
          .height(46)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.dashboard_surface_soft'))
          .borderRadius(999)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ top: 26, bottom: 26, left: 18, right: 18 })
    .backgroundColor($r('app.color.glass_bg_chip'))
    .border({
      width: 1,
      color: $r('app.color.glass_border')
    })
    .borderRadius(22)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  emptyResultSection() {
    Column({ space: 10 }) {
      Text('没有匹配的任务')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text('调整搜索词、标签或分类筛选后再试。')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
      Button('清空筛选')
        .height(40)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.accent_color'))
        .backgroundColor($r('app.color.dashboard_surface_info'))
        .borderRadius(999)
        .onClick(() => {
          this.searchQuery = '';
          this.selectedTagFilter = '';
          this.selectedCategoryFilter = '';
          this.showFilterPanel = false;
          this.headerVisible = true;
          this.contentScroller.scrollEdge(Edge.Top);
        })
    }
    .width('100%')
    .padding({ top: 28, bottom: 28 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  guestEmptySection() {
    Column({ space: 10 }) {
      Text('示例体验模式')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text('当前显示示例界面，不连接真实服务器。连接服务器后可查看真实下载队列。')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
      Button('前往连接服务器')
        .height(40)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.accent_color'))
        .backgroundColor($r('app.color.dashboard_surface_info'))
        .borderRadius(999)
        .onClick(() => {
          AppStorage.setOrCreate('currentTabIndex', 2);
        })
    }
    .width('100%')
    .padding({ top: 28, bottom: 28, left: 18, right: 18 })
    .backgroundColor($r('app.color.glass_bg_chip'))
    .border({
      width: 1,
      color: $r('app.color.glass_border')
    })
    .borderRadius(22)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  bulkActionSheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.download_overlay'))
        .onClick(() => {
          this.cancelBulkAction();
        })

      Column({ space: 14 }) {
        Row()
          .width(46)
          .height(5)
          .backgroundColor($r('app.color.download_sheet_handle'))
          .borderRadius(999)

        Column({ space: 6 }) {
          Text(`批量${this.getBulkActionLabel()} ${this.getSelectedCount()} 个任务？`)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text(`系统将${this.getBulkActionLabel()}选中的下载项，并保留当前队列顺序。`)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: 8 }) {
          ForEach(this.getAffectedNames(), (name: string) => {
            Row() {
              Text(name)
                .layoutWeight(1)
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.pendingBulkAction === 'delete' ? '移除' : this.getBulkActionLabel())
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.accent_color'))
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          }, (name: string) => name)
        }
        .width('100%')
        .padding(12)
        .backgroundColor($r('app.color.download_sheet_surface'))
        .border({
          width: 1,
          color: $r('app.color.dashboard_border_soft')
        })
        .borderRadius(18)

        Row({ space: 10 }) {
          Button('取消')
            .layoutWeight(1)
            .height(46)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.dashboard_surface_soft'))
            .borderRadius(999)
            .onClick(() => {
              this.cancelBulkAction();
            })

          Button(this.getBulkConfirmButtonText())
            .layoutWeight(1)
            .height(46)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.tab_active_fg'))
            .backgroundColor(this.pendingBulkAction === 'delete' ? $r('app.color.error_color') : $r('app.color.accent_color'))
            .borderRadius(999)
            .onClick(() => {
              this.confirmBulkAction();
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 40 })
      .backgroundColor($r('app.color.card_background'))
      .borderRadius({ topLeft: 28, topRight: 28, bottomLeft: 0, bottomRight: 0 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }

  private getListSubtitle(): string {
    if (this.guestMode) {
      return '演示队列支持搜索和筛选，不会操作真实服务器';
    }
    if (this.torrents.length === 0 && !this.isLoading) {
      return '当前没有活跃或排队中的下载任务';
    }
    if (this.showFilterPanel) {
      return '按速率、标签和状态快速定位任务';
    }
    if (this.selectionMode) {
      return `${this.getSelectedCount()} 个任务已加入批量操作`;
    }
    return '搜索、筛选、排序并批量操作';
  }

  private getListBadgeText(): string {
    if (this.guestMode) {
      return `演示 ${this.getVisibleTorrents().length} 项`;
    }
    if (this.showBulkActionSheet) {
      return '待确认';
    }
    if (this.showFilterPanel) {
      return `筛选后 ${this.getVisibleTorrents().length} 项`;
    }
    if (this.torrents.length === 0 && !this.isLoading) {
      return '0 项';
    }
    return '队列视图';
  }

  @Builder
  categoryMgmtSheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.download_overlay'))
        .onClick(() => {
          this.showCategoryMgmtSheet = false;
        })

      Column({ space: 18 }) {
        Row()
          .width(46)
          .height(5)
          .backgroundColor($r('app.color.download_sheet_handle'))
          .borderRadius(999)

        Row() {
          Column({ space: 3 }) {
            Text('分类管理')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text(`${this.categories.length} 个分类`)
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_secondary'))
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Text('完成')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.accent_color'))
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .backgroundColor($r('app.color.dashboard_surface_info'))
            .borderRadius(999)
            .onClick(() => {
              this.showCategoryMgmtSheet = false;
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row({ space: 10 }) {
          TextInput({ placeholder: '输入新分类名称…', text: this.newCategoryNameInput })
            .placeholderColor($r('app.color.tab_inactive_fg'))
            .fontSize(13)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor(Color.Transparent)
            .layoutWeight(1)
            .onChange((value: string) => {
              this.newCategoryNameInput = value;
            })
          if (this.isCreatingCategory) {
            LoadingProgress()
              .width(18)
              .height(18)
              .color($r('app.color.accent_color'))
          } else if (this.newCategoryNameInput.trim().length > 0) {
            Text('创建')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.tab_active_fg'))
              .padding({ left: 14, right: 14, top: 7, bottom: 7 })
              .backgroundColor($r('app.color.accent_color'))
              .borderRadius(999)
              .onClick(() => {
                this.handleCreateCategory();
              })
          }
        }
        .width('100%')
        .height(50)
        .padding({ left: 16, right: 12 })
        .backgroundColor($r('app.color.dashboard_surface_soft'))
        .border({
          width: 1,
          color: $r('app.color.dashboard_border')
        })
        .borderRadius(999)

        if (this.categories.length === 0) {
          Column({ space: 6 }) {
            Text('暂无分类')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_secondary'))
            Text('在上方输入名称后点击「创建」')
              .fontSize(12)
              .fontColor($r('app.color.tab_inactive_fg'))
          }
          .width('100%')
          .padding({ top: 30, bottom: 30 })
          .alignItems(HorizontalAlign.Center)
          .backgroundColor($r('app.color.dashboard_surface_soft'))
          .border({
            width: 1,
            color: $r('app.color.dashboard_border')
          })
          .borderRadius(18)
        } else {
          Column() {
            ForEach(this.categories, (name: string, index?: number) => {
              Column() {
                if (index !== undefined && index > 0) {
                  Divider()
                    .color($r('app.color.dashboard_border_soft'))
                    .margin({ left: 14 })
                }
                Row() {
                  Row()
                    .width(8)
                    .height(8)
                    .backgroundColor($r('app.color.accent_color'))
                    .borderRadius(999)
                    .margin({ right: 12 })
                  Text(name)
                    .layoutWeight(1)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text('删除')
                    .fontSize(11)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.error_color'))
                    .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                    .backgroundColor($r('app.color.dashboard_surface_danger'))
                    .borderRadius(999)
                    .onClick(() => {
                      this.handleDeleteCategory(name);
                    })
                }
                .width('100%')
                .padding({ left: 14, right: 14, top: 13, bottom: 13 })
                .alignItems(VerticalAlign.Center)
              }
            }, (name: string) => name)
          }
          .width('100%')
          .backgroundColor($r('app.color.download_sheet_surface'))
          .border({
            width: 1,
            color: $r('app.color.dashboard_border_soft')
          })
          .borderRadius(18)
          .clip(true)
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 14, bottom: 40 })
      .backgroundColor($r('app.color.card_background'))
      .borderRadius({ topLeft: 28, topRight: 28, bottomLeft: 0, bottomRight: 0 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  setCategorySheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.download_overlay'))
        .onClick(() => {
          if (!this.isSettingCategory) {
            this.showSetCategorySheet = false;
          }
        })

      Column({ space: 14 }) {
        Row()
          .width(46)
          .height(5)
          .backgroundColor($r('app.color.download_sheet_handle'))
          .borderRadius(999)

        Row() {
          Text('设置分类')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Blank()
          if (this.isSettingCategory) {
            LoadingProgress()
              .width(20)
              .height(20)
              .color($r('app.color.accent_color'))
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(`为 ${this.getSelectedCount()} 个任务选择分类`)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')

        Column({ space: 8 }) {
          Row() {
            Text('清除分类（无分类）')
              .layoutWeight(1)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_secondary'))
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(14)
              .fontColor([$r('app.color.text_secondary')])
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 12, bottom: 12 })
          .backgroundColor($r('app.color.download_sheet_surface'))
          .border({
            width: 1,
            color: $r('app.color.dashboard_border_soft')
          })
          .borderRadius(14)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            this.handleSetCategory('');
          })

          ForEach(this.categories, (name: string) => {
            Row() {
              Text(name)
                .layoutWeight(1)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(14)
                .fontColor([$r('app.color.text_secondary')])
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 12, bottom: 12 })
            .backgroundColor($r('app.color.download_sheet_surface'))
            .border({
              width: 1,
              color: $r('app.color.dashboard_border_soft')
            })
            .borderRadius(14)
            .alignItems(VerticalAlign.Center)
            .onClick(() => {
              this.handleSetCategory(name);
            })
          }, (name: string) => name)
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 40 })
      .backgroundColor($r('app.color.card_background'))
      .borderRadius({ topLeft: 28, topRight: 28, bottomLeft: 0, bottomRight: 0 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
  }
}
