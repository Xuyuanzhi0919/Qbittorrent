import { QbittorrentService } from '../service/QbittorrentService';
import { TorrentInfo } from '../model/TorrentInfo';
import { TorrentFilter } from '../service/QbittorrentService';
import { TorrentListItem } from '../components/TorrentListItem';
import { EmptyState } from '../components/EmptyState';
import { AppConstants } from '../common/constants/AppConstants';
import { AppService } from './Index';

@Component
export struct TorrentListPage {
  private service: QbittorrentService = AppService.getService();
  @State torrents: TorrentInfo[] = [];
  @State currentFilter: string = TorrentFilter.ALL;
  @State currentSort: string = 'added_on';
  @State isLoading: boolean = false;
  @State filterTabs: string[] = ['全部', '下载中', '已完成', '暂停', '活跃'];
  @State filterValues: string[] = [TorrentFilter.ALL, TorrentFilter.DOWNLOADING, TorrentFilter.COMPLETED, TorrentFilter.PAUSED, TorrentFilter.ACTIVE];
  @State selectedTab: number = 0;
  private pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    this.refreshData();
  }

  aboutToDisappear(): void {
  }

  private async refreshData(): Promise<void> {
    this.isLoading = true;
    const filter: string = this.currentFilter === TorrentFilter.ALL ? '' : this.currentFilter;
    this.torrents = await this.service.fetchTorrentList(filter, this.currentSort);
    this.isLoading = false;
  }

  private async changeFilter(index: number): Promise<void> {
    this.selectedTab = index;
    this.currentFilter = this.filterValues[index];
    await this.refreshData();
  }

  build() {
    NavDestination() {
      Column() {
        // Filter tabs
        Tabs({ index: this.selectedTab }) {
          ForEach(this.filterTabs, (tab: string, index?: number) => {
            TabContent() {
            }
            .tabBar(tab)
          }, (tab: string, index?: number) => `${index}`)
        }
        .barMode(BarMode.Scrollable)
        .onChange((index: number) => {
          this.changeFilter(index);
        })
        .height(48)

        // Torrent list
        if (this.torrents.length === 0 && !this.isLoading) {
          EmptyState({ message: '暂无种子', icon: '📭' })
        } else {
          List({ space: 8 }) {
            ForEach(this.torrents, (torrent: TorrentInfo) => {
              ListItem() {
                TorrentListItem({
                  torrent: torrent,
                  onItemClick: (hash: string) => {
                    this.pathStack.pushPath({ name: 'TorrentDetail', param: hash });
                  }
                })
              }
              .swipeAction({ end: this.swipeActionBuilder(torrent) })
            }, (torrent: TorrentInfo) => torrent.hash)
          }
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .scrollBar(BarState.Off)
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
    }
    .title('种子列表')
    .backgroundColor($r('app.color.page_background'))
    .menus([
      {
        value: '添加种子',
        icon: '',
        action: () => {
          this.pathStack.pushPath({ name: 'AddTorrent' });
        }
      }
    ])
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
    })
  }

  @Builder
  swipeActionBuilder(torrent: TorrentInfo) {
    Row({ space: 8 }) {
      if (torrent.isPaused()) {
        Button('恢复')
          .fontSize(13)
          .fontColor('#FFFFFF')
          .backgroundColor($r('app.color.download_color'))
          .borderRadius(8)
          .height(40)
          .onClick(async () => {
            await this.service.resumeTorrents([torrent.hash]);
            this.refreshData();
          })
      } else {
        Button('暂停')
          .fontSize(13)
          .fontColor('#FFFFFF')
          .backgroundColor($r('app.color.state_paused'))
          .borderRadius(8)
          .height(40)
          .onClick(async () => {
            await this.service.pauseTorrents([torrent.hash]);
            this.refreshData();
          })
      }
      Button('删除')
        .fontSize(13)
        .fontColor('#FFFFFF')
        .backgroundColor($r('app.color.button_danger'))
        .borderRadius(8)
        .height(40)
        .onClick(async () => {
          await this.service.deleteTorrents([torrent.hash], false);
          this.refreshData();
        })
    }
  }
}
