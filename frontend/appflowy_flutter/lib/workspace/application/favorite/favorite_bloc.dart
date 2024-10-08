import 'package:appflowy/workspace/application/favorite/favorite_service.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_result/appflowy_result.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'favorite_listener.dart';

part 'favorite_bloc.freezed.dart';

class FavoriteBloc extends Bloc<FavoriteEvent, FavoriteState> {
  FavoriteBloc() : super(FavoriteState.initial()) {
    _dispatch();
  }

  final _service = FavoriteService();
  final _listener = FavoriteListener();

  @override
  Future<void> close() async {
    await _listener.stop();
    return super.close();
  }

  void _dispatch() {
    on<FavoriteEvent>(
      (event, emit) async {
        await event.when(
          initial: () async {
            _listener.start(
              favoritesUpdated: _onFavoritesUpdated,
            );
            add(const FavoriteEvent.fetchFavorites());
          },
          fetchFavorites: () async {
            final result = await _service.readFavorites();
            emit(
              result.fold(
                (favoriteViews) {
                  final views = favoriteViews.items.map((v) => v.item).toList();
                  final pinnedViews = views.where((v) => v.isPinned).toList();
                  final unpinnedViews =
                      views.where((v) => !v.isPinned).toList();
                  return state.copyWith(
                    views: views,
                    pinnedViews: pinnedViews,
                    unpinnedViews: unpinnedViews,
                  );
                },
                (error) => state.copyWith(
                  views: [],
                ),
              ),
            );
          },
          toggle: (view) async {
            if (view.isFavorite) {
              await _service.unpinFavorite(view);
            } else if (state.pinnedViews.length < 3) {
              // pin the view if there are less than 3 pinned views
              await _service.pinFavorite(view);
            }

            await _service.toggleFavorite(
              view.id,
              !view.isFavorite,
            );
          },
          pin: (view) async {
            await _service.pinFavorite(view);
            add(const FavoriteEvent.fetchFavorites());
          },
          unpin: (view) async {
            await _service.unpinFavorite(view);
            add(const FavoriteEvent.fetchFavorites());
          },
        );
      },
    );
  }

  void _onFavoritesUpdated(
    FlowyResult<RepeatedViewPB, FlowyError> favoriteOrFailed,
    bool didFavorite,
  ) {
    favoriteOrFailed.fold(
      (favorite) => add(const FetchFavorites()),
      (error) => Log.error(error),
    );
  }
}

@freezed
class FavoriteEvent with _$FavoriteEvent {
  const factory FavoriteEvent.initial() = Initial;
  const factory FavoriteEvent.toggle(ViewPB view) = ToggleFavorite;
  const factory FavoriteEvent.fetchFavorites() = FetchFavorites;
  const factory FavoriteEvent.pin(ViewPB view) = PinFavorite;
  const factory FavoriteEvent.unpin(ViewPB view) = UnpinFavorite;
}

@freezed
class FavoriteState with _$FavoriteState {
  const factory FavoriteState({
    required List<ViewPB> views,
    @Default([]) List<ViewPB> pinnedViews,
    @Default([]) List<ViewPB> unpinnedViews,
  }) = _FavoriteState;

  factory FavoriteState.initial() => const FavoriteState(
        views: [],
      );
}
