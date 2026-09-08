import 'package:dio/dio.dart';

import '../../errors/failures.dart';

typedef DioFailureTransformer = Failure Function(DioException error);

/// Places the normalized domain failure on DioException.error while preserving
/// the original response, request options, type, and stack trace.
class ErrorTransformerInterceptor extends Interceptor {
  const ErrorTransformerInterceptor({required this.transformer});

  final DioFailureTransformer transformer;

  @override
  void onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) {
    final Failure failure = transformer(error);
    handler.next(
      error.copyWith(
        error: failure,
        message: failure.message,
      ),
    );
  }
}
