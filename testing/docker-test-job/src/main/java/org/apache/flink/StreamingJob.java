/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.apache.flink;

import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.api.connector.source.Boundedness;
import org.apache.flink.api.connector.source.ReaderOutput;
import org.apache.flink.api.connector.source.Source;
import org.apache.flink.api.connector.source.SourceReader;
import org.apache.flink.api.connector.source.SourceReaderContext;
import org.apache.flink.api.connector.source.SourceSplit;
import org.apache.flink.api.connector.source.SplitEnumerator;
import org.apache.flink.api.connector.source.SplitEnumeratorContext;
import org.apache.flink.core.io.InputStatus;
import org.apache.flink.core.io.SimpleVersionedSerializer;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;

import javax.annotation.Nullable;

import java.io.IOException;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.CompletableFuture;

public class StreamingJob {

	public static void main(String[] args) throws Exception {
		final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
		env.fromSource(new InfiniteSource(), WatermarkStrategy.noWatermarks(), "source")
				.map(x -> x);
		env.execute();
	}

	/** Infinite source for testing. */
	private static final class InfiniteSource
			implements Source<Integer, DummySplit, NoOpEnumState> {
		@Override
		public Boundedness getBoundedness() {
			return Boundedness.CONTINUOUS_UNBOUNDED;
		}

		@Override
		public SplitEnumerator<DummySplit, NoOpEnumState> createEnumerator(
				SplitEnumeratorContext<DummySplit> splitEnumeratorContext) throws Exception {
			return new NoOpEnumerator();
		}

		@Override
		public SplitEnumerator<DummySplit, NoOpEnumState> restoreEnumerator(
				SplitEnumeratorContext<DummySplit> splitEnumeratorContext,
				NoOpEnumState noOpEnumState)
				throws Exception {
			return new NoOpEnumerator();
		}

		@Override
		public SimpleVersionedSerializer<DummySplit> getSplitSerializer() {
			return new DummySplitSerializer();
		}

		@Override
		public SimpleVersionedSerializer<NoOpEnumState> getEnumeratorCheckpointSerializer() {
			return new NoOpEnumStateSerializer();
		}

		@Override
		public SourceReader<Integer, DummySplit> createReader(
				SourceReaderContext sourceReaderContext) throws Exception {
			return new InfiniteSourceReader();
		}
	}

	/** Reader for {@link InfiniteSource}. */
	private static class InfiniteSourceReader implements SourceReader<Integer, DummySplit> {

		@Override
		public InputStatus pollNext(ReaderOutput<Integer> readerOutput) throws Exception {
			Thread.sleep(20);
			return InputStatus.MORE_AVAILABLE;
		}

		@Override
		public List<DummySplit> snapshotState(long l) {
			return Collections.singletonList(new DummySplit());
		}

		@Override
		public CompletableFuture<Void> isAvailable() {
			return CompletableFuture.completedFuture(null);
		}

		@Override
		public void start() {
			// no op
		}

		@Override
		public void addSplits(List<DummySplit> list) {
			// no op
		}

		@Override
		public void notifyNoMoreSplits() {
			// no op
		}

		@Override
		public void close() throws Exception {
			// no op
		}
	}

	/** Mock enumerator. */
	private static class NoOpEnumerator implements SplitEnumerator<DummySplit, NoOpEnumState> {
		@Override
		public void start() {}

		@Override
		public void handleSplitRequest(int subtaskId, @Nullable String requesterHostname) {}

		@Override
		public void addSplitsBack(List<DummySplit> splits, int subtaskId) {}

		@Override
		public void addReader(int subtaskId) {}

		@Override
		public NoOpEnumState snapshotState(long checkpointId) throws Exception {
			return new NoOpEnumState();
		}

		@Override
		public void close() throws IOException {}
	}

	/** The split of the {@link InfiniteSource}. */
	private static class DummySplit implements SourceSplit {
		public static final String SPLIT_ID = "DummySplitId";

		@Override
		public String splitId() {
			return SPLIT_ID;
		}
	}

	/** Dummy enum state. */
	private static class NoOpEnumState {}

	/** Mock enumerator state serializer. */
	private static class NoOpEnumStateSerializer
			implements SimpleVersionedSerializer<NoOpEnumState> {
		@Override
		public int getVersion() {
			return 0;
		}

		@Override
		public byte[] serialize(NoOpEnumState obj) throws IOException {
			return new byte[0];
		}

		@Override
		public NoOpEnumState deserialize(int version, byte[] serialized) throws IOException {
			return new NoOpEnumState();
		}
	}

	private static class DummySplitSerializer implements SimpleVersionedSerializer<DummySplit> {

		@Override
		public int getVersion() {
			return 0;
		}

		@Override
		public byte[] serialize(DummySplit obj) throws IOException {
			return new byte[0];
		}

		@Override
		public DummySplit deserialize(int version, byte[] serialized) throws IOException {
			return new DummySplit();
		}
	}
}