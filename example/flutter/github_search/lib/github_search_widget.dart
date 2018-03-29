import 'dart:async';

import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';

// The Model represents the data the View requires. The View consumes a Stream
// of Models. The view rebuilds every time the Stream emits a new Model!
//
// The Model Stream will emit new Models depending on the State of the app: The
// initial state, loading states, the list of results, and any errors that
// happen.
//
// The Model Stream responds to input from the View by accepting a
// Stream<String>. We call this Stream the onTextChanged "intent".
class SearchModel {
  final SearchResult result;
  final bool hasError;
  final bool isLoading;

  SearchModel({
    this.result,
    this.hasError = false,
    this.isLoading = false,
  });

  factory SearchModel.initial() =>
      new SearchModel(result: new SearchResult.noTerm());

  factory SearchModel.loading() => new SearchModel(isLoading: true);

  static Stream<SearchModel> stream(
    Stream<String> onTextChanged,
    GithubApi api,
  ) {
    return new Observable<String>(onTextChanged)
        // If the text has not changed, do not perform a new search
        .distinct()
        // Wait for the user to stop typing for 250ms before running a search
        .debounce(const Duration(milliseconds: 250))
        // Call the Github api with the given search term and convert it to a
        // Model. If another search term is entered, switchMap will ensure
        // the previous search is discarded so we don't deliver stale results
        // to the View.
        .switchMap(_buildSearch(api))
        // The initial state of the model.
        .startWith(new SearchModel.initial());
  }

  static Stream<SearchModel> Function(String) _buildSearch(GithubApi api) {
    return (String term) {
      return api
          .search(term)
          .map((SearchResult result) {
            return new SearchModel(
              result: result,
              isLoading: false,
            );
          })
          .onErrorReturn(new SearchModel(hasError: true))
          .startWith(new SearchModel.loading());
    };
  }
}

// The View in a Stream-based architecture takes two arguments: The Model Stream
// and the onTextChanged callback. In our case, the onTextChanged callback will
// emit the latest String to a Stream<String> whenever it is called.
//
// The Model will use the Stream<String> to send new search requests to the
// GithubApi.
class SearchView extends StatelessWidget {
  final Stream<SearchModel> model;
  final ValueChanged<String> onTextChanged;

  SearchView({
    Key key,
    @required this.model,
    @required this.onTextChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new StreamBuilder<SearchModel>(
      stream: model,
      initialData: new SearchModel.initial(),
      builder: (BuildContext context, AsyncSnapshot<SearchModel> snapshot) {
        final model = snapshot.data;

        return new Scaffold(
          body: new Stack(
            children: <Widget>[
              new Flex(direction: Axis.vertical, children: <Widget>[
                new Container(
                  padding: new EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 4.0),
                  child: new TextField(
                    decoration: new InputDecoration(
                      hideDivider: true,
                      hintText: 'Search Github...',
                    ),
                    style: new TextStyle(
                      fontSize: 36.0,
                      fontFamily: "Hind",
                      decoration: TextDecoration.none,
                    ),
                    onChanged: onTextChanged,
                  ),
                ),
                new Expanded(
                  child: new Stack(
                    children: <Widget>[
                      // Fade in an intro screen if no term has been entered
                      new SearchIntroWidget(model.result?.isNoTerm ?? false),

                      // Fade in an Empty Result screen if the search contained
                      // no items
                      new EmptyResultWidget(model.result?.isEmpty ?? false),

                      // Fade in a loading screen when results are being fetched
                      // from Github
                      new SearchLoadingWidget(model.isLoading ?? false),

                      // Fade in an error if something went wrong when fetching
                      // the results
                      new SearchErrorWidget(model.hasError ?? false),

                      // Fade in the Result if available
                      new SearchResultWidget(model.result),
                    ],
                  ),
                )
              ])
            ],
          ),
        );
      },
    );
  }
}
