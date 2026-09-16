"""create ai coach tables

Revision ID: e7b91f03d52c
Revises: 995c2dc9ea3a
Create Date: 2026-09-16 23:58:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e7b91f03d52c'
down_revision: Union[str, Sequence[str], None] = '995c2dc9ea3a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'coach_messages',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('user_id', sa.String(length=36), nullable=False),
        sa.Column('sender', sa.String(length=20), nullable=False),
        sa.Column('message', sa.Text(), nullable=False),
        sa.Column('mode', sa.String(length=50), nullable=False),
        sa.Column('context_metadata', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_coach_messages_id'), 'coach_messages', ['id'], unique=False)
    op.create_index(op.f('ix_coach_messages_user_id'), 'coach_messages', ['user_id'], unique=False)

    op.create_table(
        'coach_insights',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('user_id', sa.String(length=36), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('category', sa.String(length=100), nullable=False),
        sa.Column('summary', sa.Text(), nullable=False),
        sa.Column('action_recommendation', sa.Text(), nullable=False),
        sa.Column('impact_metric', sa.String(length=100), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_coach_insights_id'), 'coach_insights', ['id'], unique=False)
    op.create_index(op.f('ix_coach_insights_user_id'), 'coach_insights', ['user_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_coach_insights_user_id'), table_name='coach_insights')
    op.drop_index(op.f('ix_coach_insights_id'), table_name='coach_insights')
    op.drop_table('coach_insights')

    op.drop_index(op.f('ix_coach_messages_user_id'), table_name='coach_messages')
    op.drop_index(op.f('ix_coach_messages_id'), table_name='coach_messages')
    op.drop_table('coach_messages')
